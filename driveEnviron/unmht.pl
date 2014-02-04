#!/usr/bin/perl -w

use strict;

=pod

=head1 NAME

B<unmht> - Unpack a MIME HTML archive


=head1 SYNOPSIS

B<unmht> unpacks MIME HTML archives that some browsers (such as Opera) save
by default.  The file extensions of such archives are .mht or .mhtml.

The first HTML file in the archive is taken to be the primary web page, the
other contained files for "page requisites" such as images or frames.  The
primary web page is written to the output directory (the current directory by
default), the requisites to a subdirectory named after the primary HTML file
name without extension, with "_files" appended.  Link URLs in all HTML
files referring to requisites are rewritten to point to the saved files.


=head1 OPTIONS

=over

=item B<-h>, B<-?>, B<--help>

Print a brief usage summary.

=item B<-l>, B<--list>

List archive contents instead of unpacking.  Four columns are output: file
name, MIME type, size and URL.  Unavailable entries are replaced by "(?)".

=item B<-o> I<directory>, B<--output> I<directory>

Unpack to I<directory> instead of current directory.

=back


=head1 SEE ALSO

http://www.volkerschatz.com/unix/uware/unmht.html

http://www.loganowen.com/mht-rip/

http://sourceforge.net/projects/mhtconv/


=head1 COPYLEFT

B<unmht> is Copyright (c) 2012 Volker Schatz.  It may be copied and/or
modified under the same terms as Perl.

=cut

use URI;
use MIME::Base64;
use MIME::QuotedPrint;
use HTML::PullParser;
use HTML::Tagset;
use Getopt::Long;


# Add approriate ordinal suffix to a number.
# -> Number
# <- String of number with ordinal suffix
sub ordinal
{
    return $_[0]."th" if $_[0] > 3 && $_[0] < 20;
    my $unitdig= $_[0] % 10;
    return $_[0]."st" if $unitdig == 1;
    return $_[0]."nd" if $unitdig == 2;
    return $_[0]."rd" if $unitdig == 3;
    return $_[0]."th";
}


# Join a list of words with a list of separators.
# -> Reference to array of separators; will be used cyclically
#    Reference to array of words
# <- String containung joined words
sub joinwith
{
    my ($seps, @words)= @_;
    return "" unless @words;
    my $all= $words[0];
    my ($sepind, $wordind)= (0, 1);
    while( defined($words[$wordind]) ) {
        $sepind= 0 unless defined($$seps[$sepind]);
        $all .= $$seps[$sepind] . $words[$wordind];
        ++$sepind;
        ++$wordind;
    }
    return $all;
}


{
my %taken;

# Find unique file name.
# -> Preferred file name, or undef
#    MHT archive name (as a fallback if no name given)
# <- File name not conflicting with names returned by previous calls, but which
#    may exist!
sub unique_name
{
    my ($fname, $mhtname)= @_;
    my ($trunc, $ext);

    if( defined $fname ) {
        $fname =~ s/^\s+//;
        $fname =~ s/\s+$//;
        $taken{$fname}= 1, return $fname unless $taken{$fname};
        ($trunc, $ext)= $fname =~ /^(.*?)(?:\.(\w+))?$/;
        $ext //= "";
    }
    else {
        $trunc= $mhtname || "unpack";
        $trunc =~ s/\.mht(?:ml?)?$//i;
        $ext= "";
    }
    for my $suff (1..9999) {
        $fname= "${trunc}_$suff.$ext";
        $taken{$fname}= 1, return $fname unless $taken{$fname};
        ++$suff;
    }
    return undef;
}

}


my %opt;
my @optdescr= ( 'output|o=s', 'list|l!', 'help|h|?!' );

my $status= GetOptions(\%opt, @optdescr);


if( !$status || $opt{help} ) {
    print <<EOF;
Usage: unmht [ -l | --list | -o <dir> | --output <dir> ] <MHT file>
By default, unpacks an MHT archive (an archive type saved by some browsers) to
the current directory.  The first HTML file in the archive is taken for the
primary web page, and all other contained files are written to a directory
named after that HTML file.  Options:
-l, --list    List archive contents (file name, MIME type, size and URL)
-o, --output  Unpack to directory <dir>
Use the command "pod2man unmht > unmht.1" or
"pod2html unmht > unmht.html" to extract the manual.
EOF
    exit !$status;
}

if( $opt{output} ) {
    if( -d $opt{output} ) {
        $opt{prefix}= $opt{output};
        $opt{prefix}.= "/";
    }
    elsif( $opt{output} !~ /\// ) {
        $opt{oname}= $opt{output};
        $opt{otrunc}= $opt{oname};
        $opt{otrunc} =~ s/\.\w+$//;
        $opt{prefix}= "";
    }
    else {
        @opt{"prefix", "oname"}= $opt{output} =~ m!^(.*/)([^/]*)$!;
        $opt{otrunc}= $opt{oname};
        $opt{otrunc} =~ s/\.\w+$//;
    }
}
else {
    $opt{prefix}= "";
}

<>; <>; # my hack to skip the first two lines on my .mht file
my $firstline= <>;

$firstline =~ m!Content-Type: multipart/related;.* boundary=(.*)$!
 or die "Can't find Content-Type header - not a MIME HTML file?\n";

my $outdir= $opt{oname} ? "$opt{otrunc}_files" : "unpackmht-$$";
unless( $opt{oname} && -d "$opt{prefix}$outdir" ) {
    mkdir "$opt{prefix}$outdir" or die "Could not create output directory.";
}

my $boundary= $1;
my %by_url;
my @htmlfiles;
my $fh;

{
    $/= "\n--$boundary\n";
    <>;
    my $fileind= 1;
    while( defined( my $data= <> ) ) {
        my %headers;
        while( $data =~ s/^([-\w]+): (.*)\n// ) {
            $headers{$1}= $2;
        }
        $data =~ s/^\n//;
        chomp $data;
        $data .= "\n";
        my ($type, $origname);
        if( defined($headers{"Content-Type"}) && $headers{"Content-Type"} =~ /\bname=(.*?)(?:;|$)/ ) {
            $origname= $1;
            ($type)= $headers{"Content-Type"} =~ /^(\w+\/\w+)\b/;
            $type //= "";
        }
        elsif( defined($headers{"Content-Disposition"}) && $headers{"Content-Disposition"} =~ /\bfilename=(.*?)(?:;|$)/ ) {
            $origname= $1;
            $type= $origname =~ /\.html?$/i ? "text/html" : "";
        }
        my $fname= unique_name($origname, $ARGV[0]);
        if( !defined($headers{"Content-Transfer-Encoding"}) ) {
            print STDERR "Warning: Encoding of ", ordinal($fileind), " file not found - leaving as-is.\n";
        }
        elsif( $headers{"Content-Transfer-Encoding"} =~ /\bbase64\b/i ) {
            $data= MIME::Base64::decode($data);
        }
        elsif( $headers{"Content-Transfer-Encoding"} =~ /\bquoted-printable\b/i ) {
            $data= MIME::QuotedPrint::decode($data);
        }
        if( $opt{list} ) {
            $origname =~ s/\s+$// if defined $origname;
            my $size= length($data);
            print $fname // "(?)", "\t", $type || "(?)", "\t$size\t",
                    $headers{"Content-Location"} // "(?)", "\n";
            next;
        }
        $headers{fname}= $fname;
        if( $headers{"Content-Location"} ) {
            $headers{url}= $headers{"Content-Location"};
            $headers{url} =~ s/\s+$//;
            $by_url{$headers{url}}= \%headers;
        }
        if( $type eq "text/html" ) {
            $headers{data}= $data;
            push @htmlfiles, \%headers;
        }
        else {
            $fname= "$opt{prefix}$outdir/$fname";
            open $fh, ">$fname" or die "Could not create file $fname";
            print $fh $data;
            close $fh;
        }
    }
    continue { ++$fileind; }
}


my $firsthtml= shift @htmlfiles;

if( $firsthtml ) {
    if( $opt{oname} ) {
        $firsthtml->{fname}= $opt{oname};
        $firsthtml->{fname} .= ".html" unless $firsthtml->{fname} =~ /\./;
    }
    else {     # output dir is already correct if we have oname
        my $dirname= $firsthtml->{fname};
        $dirname =~ s/\.\w+$//;
        $dirname= "${dirname}_files";
        if( -e $dirname ) {
            system "mv \"$opt{prefix}$outdir\"/* \"$opt{prefix}$dirname\"";
            rmdir $outdir;
            $outdir= $dirname;
        }
        else {
            rename "$opt{prefix}$outdir", "$opt{prefix}$dirname" and $outdir= $dirname;
        }
    }
    my $linksubst= "";
    my $p= HTML::PullParser->new( doc => \$firsthtml->{data}, "start" => 'text, attr, tagname', "text" => 'text', "end" => 'text' );
    while( defined( my $tok= $p->get_token()) ) {
        my $linkary;
        my @linkattrs;
        if( ref($tok->[1]) && ($linkary= $HTML::Tagset::linkElements{$tok->[2]})
                && (@linkattrs= grep $tok->[1]->{$_}, @$linkary) ) {
            for my $attr (@linkattrs) {
                my $uri= URI->new($tok->[1]->{$attr});
                $uri= $uri->abs($firsthtml->{url});
#                print "substituting\n$tok->[1]->{$attr}\nby\n$outdir/$by_url{$uri->as_string()}->{fname}\n"
#                    if $by_url{$uri->as_string()};
                $tok->[1]->{$attr}= "$outdir/" . $by_url{$uri->as_string()}->{fname}
                    if $by_url{$uri->as_string()};
            }
            delete $tok->[1]->{"/"};    # parser bug with <xhtml /> tags
            if( grep $_ eq "/", keys %{$tok->[1]} ) {
                print "/ key: $tok->[0]\n$tok->[2]  ", join("  ", map $_." => ".$tok->[1]->{$_}, keys %{$tok->[1]}), "\n";
            }
            $linksubst .= "<$tok->[2] " . join(" ", map("$_=\"$tok->[1]->{$_}\"", keys %{$tok->[1]})) . ">";
        }
        else {
            $linksubst .= $tok->[0];
        }
    }
    open $fh, ">$opt{prefix}$firsthtml->{fname}" or die "Could not create file $firsthtml->{fname}";
    print $fh $linksubst;
    close $fh;
}


for my $html (@htmlfiles) {
    my $linksubst= "";
    my $p= HTML::PullParser->new( doc => \$html->{data}, "start" => 'text, attr, tagname', "text" => 'text', "end" => 'text' );
    while( defined( my $tok= $p->get_token()) ) {
        my $linkary;
        my @linkattrs;
        if( ref($tok->[1]) && ($linkary= $HTML::Tagset::linkElements{$tok->[2]})
                && (@linkattrs= grep $tok->[1]->{$_}, @$linkary) ) {
            for my $attr (@linkattrs) {
                my $uri= URI->new($tok->[1]->{$attr});
                $uri= $uri->abs($html->{url});
                $tok->[1]->{$attr}= $by_url{$uri->as_string()}->{fname}
                    if $by_url{$uri->as_string()};
            }
            delete $tok->[1]->{"/"};
            $linksubst .= "<$tok->[2] " . join(" ", map("$_=\"$tok->[1]->{$_}\"", keys %{$tok->[1]})) . ">";
        }
        else {
            $linksubst .= $tok->[0];
        }
    }
    open $fh, ">$opt{prefix}$outdir/$html->{fname}" or die "Could not create file $outdir/$html->{fname}";
    print $fh $linksubst;
    close $fh;
}

