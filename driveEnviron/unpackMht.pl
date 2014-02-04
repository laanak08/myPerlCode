#!/usr/bin/perl
use chilkat;

$mht = new chilkat::CkMht();

$success = $mht->UnlockComponent("Anything for 30-day trial");
if ($success != 1) {
    print $mht->lastErrorText() . "\r\n";
    exit;
}

$mhtDoc = <"/home/marcelle/Downloads/DRIVEEnvironmentMap.mht">;

#  Now extract the HTML and embedded objects:
$unpackDir = "/home/marcelle/programming/perl/REperl/driveEnviron/temp/";
$htmlFilename = "driveMap.html";
$partsSubdir = "objects";
#  Extract to /Users/chilkat/temp/gopackaging.html.
#  images and other embedded objects are placed in
#  /Users/chilkat/temp/objects.  Directories are automatically
#  created if they don't already exist.
$success = $mht->UnpackMHTString($mhtDoc,$unpackDir,$htmlFilename,$partsSubdir);
if ($success != 1) {
    print $mht->lastErrorText() . "\r\n";
}
else {
    print "Unpacked!" . "\n";
}
