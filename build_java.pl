#use strict;
use Cwd qw(abs_path);
use File::Find;
use File::Compare;
use File::Basename;
use File::stat;
use File::Copy;

my @excluded_sources = qw(
provider\.new/
org/mozilla/jss/provider/java/security/KeyFactorySpi1_4\.java
org/mozilla/jss/pkix/cert/X509Certificate\.java
samples/
);

my @javah_classes = qw(
org.mozilla.jss.DatabaseCloser        
org.mozilla.jss.CryptoManager          
org.mozilla.jss.crypto.Algorithm        
org.mozilla.jss.crypto.EncryptionAlgorithm      
org.mozilla.jss.crypto.PQGParams     
org.mozilla.jss.crypto.SecretDecoderRing
org.mozilla.jss.asn1.ASN1Util
org.mozilla.jss.pkcs11.CertProxy        
org.mozilla.jss.pkcs11.CipherContextProxy 
org.mozilla.jss.pkcs11.PK11Module 
org.mozilla.jss.pkcs11.ModuleProxy 
org.mozilla.jss.pkcs11.PK11Cert     
org.mozilla.jss.pkcs11.PK11Cipher     
org.mozilla.jss.pkcs11.PK11KeyWrapper  
org.mozilla.jss.pkcs11.PK11MessageDigest 
org.mozilla.jss.pkcs11.PK11PrivKey   
org.mozilla.jss.pkcs11.PK11PubKey     
org.mozilla.jss.pkcs11.PK11SymKey      
org.mozilla.jss.pkcs11.PK11KeyPairGenerator 
org.mozilla.jss.pkcs11.PK11SymmetricKeyDeriver
org.mozilla.jss.pkcs11.PK11KeyGenerator
org.mozilla.jss.pkcs11.PK11Token
org.mozilla.jss.pkcs11.PrivateKeyProxy  
org.mozilla.jss.pkcs11.PublicKeyProxy    
org.mozilla.jss.pkcs11.SymKeyProxy
org.mozilla.jss.pkcs11.KeyProxy    
org.mozilla.jss.pkcs11.PK11Token    
org.mozilla.jss.pkcs11.TokenProxy    
org.mozilla.jss.pkcs11.PK11Signature  
org.mozilla.jss.pkcs11.PK11Store       
org.mozilla.jss.pkcs11.PK11KeyPairGenerator 
org.mozilla.jss.pkcs11.SigContextProxy
org.mozilla.jss.pkcs11.PK11RSAPublicKey
org.mozilla.jss.pkcs11.PK11DSAPublicKey
org.mozilla.jss.pkcs11.PK11ECPublicKey
org.mozilla.jss.pkcs11.PK11SecureRandom 
org.mozilla.jss.provider.java.security.JSSKeyStoreSpi
org.mozilla.jss.SecretDecoderRing.KeyManager
org.mozilla.jss.ssl.SSLSocket 
org.mozilla.jss.ssl.SSLServerSocket 
org.mozilla.jss.ssl.SocketBase 
org.mozilla.jss.util.Password       
);

my @packages = qw(
org.mozilla.jss
org.mozilla.jss.asn1
org.mozilla.jss.crypto
org.mozilla.jss.pkcs7
org.mozilla.jss.pkcs10
org.mozilla.jss.pkcs11
org.mozilla.jss.pkcs12
org.mozilla.jss.pkix.primitive
org.mozilla.jss.pkix.cert
org.mozilla.jss.pkix.cmc
org.mozilla.jss.pkix.cmmf
org.mozilla.jss.pkix.cms
org.mozilla.jss.pkix.crmf
org.mozilla.jss.provider.java.security
org.mozilla.jss.provider.javax.crypto
org.mozilla.jss.SecretDecoderRing
org.mozilla.jss.ssl
org.mozilla.jss.tests
org.mozilla.jss.util
);

# setup environment
setup_env();

# setup variables
setup_vars(\@ARGV);

# run the command with its arguments
my $cmd = (shift || "build");   # first argument is command
grep { s/(.*)/"$1"/ } @ARGV;    # enclose remaining arguments in quotes
my $args = join(",",@ARGV);     # and comma-separate them
eval "$cmd($args)";             # now run the command
if( $@ ) {
    die $@;                     # errors in eval will be put in $@
}

# END

my %cmdline_vars;
sub grab_cmdline_vars {
    my $argv = shift;

    while( $$argv[0] =~ /(.+)=(.*)/ ) {
        $cmdline_vars{$1} = $2;
        shift @$argv;
    }
}

sub dump_cmdline_vars {
    print "Command variables:\n";
    for(keys %cmdline_vars) {
        print "$_=" . $cmdline_vars{$_} . "\n";
    }
}

sub setup_env {
    # check that JAVA_HOME environment variable has been set externally
    $ENV{JAVA_HOME} or
    die "\nMust specify JAVA_HOME environment variable!\n"
      . "(e. g. - export JAVA_HOME=/etc/alternatives/java_sdk_1.8.0_openjdk)"
      . "\n\n";
    print "JAVA_HOME=$ENV{'JAVA_HOME'}\n";

    # check that USE_64 environment variable has been set externally
    # for 64-bit architectures (when applicable)
    my $bitsize = `getconf LONG_BIT`;
    if( $bitsize == 64 ) {
        $ENV{USE_64} or
        die "\nMust specify USE_64 environment variable!\n"
          . "(e. g. - export USE_64=1)\n\n";
        print "USE_64=$ENV{'USE_64'}\n";
    }
}

sub setup_vars {
    my $argv = shift;

    grab_cmdline_vars($argv);
    dump_cmdline_vars();

    our $jar = "$ENV{JAVA_HOME}/bin/jar";
    our $javac = "$ENV{JAVA_HOME}/bin/javac";
    our $javah = "$ENV{JAVA_HOME}/bin/javah";
    our $javadoc = "$ENV{JAVA_HOME}/bin/javadoc";

    our $dist_dir = abs_path($cmdline_vars{SOURCE_PREFIX});

    our $class_dir = "$dist_dir/classes";
    our $class_jar = "$dist_dir/$cmdline_vars{XPCLASS_JAR}";

    our $class_release_dir = $cmdline_vars{SOURCE_RELEASE_PREFIX};
    $class_release_dir .= "/$cmdline_vars{SOURCE_RELEASE_CLASSES_DIR}";

    our $javac_opt_flag = "-g";
    if( $ENV{BUILD_OPT} ) {
        $javac_opt_flag = "-O";
    }

    our $jni_header_dir = "$dist_dir/private/jss/_jni";

    our $jarFiles = "/usr/share/java/slf4j/slf4j-api.jar:/usr/share/java/commons-codec.jar";
    if( $ENV{DEBIAN_BUILD} ) {
        $jarFiles = "/usr/share/java/slf4j-api.jar:/usr/share/java/commons-codec.jar";
    }

    our $classpath = "-classpath $jarFiles:/usr/share/java/commons-lang.jar";
    my $jce_jar = $ENV{JCE_JAR};
    if( $jce_jar ) {
        $classpath .= ":$jce_jar";
    }

    our $javac_deprecation_flag = "";
    if( $ENV{CHECK_DEPRECATION} ) {
        $javac_deprecation_flag = "-Xlint:deprecation";
    }

    # retrieve present working directory
    our $jss_dir = `pwd`;
    $jss_dir =~ chomp $jss_dir;
    print "JSS directory: $jss_dir\n";

    my $work_dir = dirname($jss_dir);
    print "Working directory: $work_dir\n";

    # retrieve operating system
    our $os = `uname`;
    $os =~ chomp $os;

    our $jss_objdir = "$work_dir/dist/$cmdline_vars{JSS_OBJDIR_NAME}";
    print "jss_objdir=$jss_objdir\n";

    my $jss_objdir_name;
    our $nss_bin_dir;
    our $nss_lib_dir;
    if( ( $ENV{USE_INSTALLED_NSPR} ) && ( $ENV{USE_INSTALLED_NSS} ) ) {
        print "Using the NSPR and NSS installed on the system to build JSS.\n";

        $nss_lib_dir = $ENV{NSS_LIB_DIR};
        $nss_lib_dir =~ s/^\s+|\s+$//g;  # trim spaces

    } else {
        # Verify existence of work area
        if(( ! -d "$work_dir/nspr" ) ||
           ( ! -d "$work_dir/nss" )  ||
           ( ! -d "$jss_dir" )) {
            my $workarea = "\nA work area must first be prepared; for example:\n\n"
                         . "    mkdir sandbox\n"
                         . "    cd sandbox\n"
                         . "    hg clone https://hg.mozilla.org/projects/nspr\n"
                         . "    hg clone https://hg.mozilla.org/projects/nss\n"
                         . "    hg clone https://hg.mozilla.org/projects/jss\n"
                         . "    cd ..\n\n";
            
            die "$workarea";
        }
        
        # Build NSS if not already built
        my $nss_latest_objdir = "$dist_dir/latest";

        if( ! -e $nss_latest_objdir ) {
            print("########################\n" .
                  "# BEGIN:  Building NSS #\n" .
                  "########################\n");
            print_do("cd $work_dir/nss;make clean nss_build_all;cd $jss_dir");
            print("######################\n" .
                  "# END:  Building NSS #\n" .
                  "######################\n");
        }

        my $nss_objdir_name = `cat $nss_latest_objdir`;
        chomp($nss_objdir_name);

        $nss_bin_dir = "$dist_dir/$nss_objdir_name/bin";
        $nss_lib_dir = "$dist_dir/$nss_objdir_name/lib";

        $jss_objdir_name = $nss_objdir_name;
        $jss_objdir_name =~ s/_cc//;

        # create a JSS OBJDIR_NAME symlink to NSS OBJDIR_NAME
        if( ! -l $jss_objdir ) {
            my $cmd = "cd $work_dir/dist;"
                    . "ln -s $nss_objdir_name $jss_objdir_name;"
                    . "cd $jss_dir";
            print_do($cmd);
        }
    }

    print "nss_bin_dir=$nss_bin_dir\n";
    print "nss_lib_dir=$nss_lib_dir\n";

    our $jss_lib_dir = "$jss_objdir/lib";
    print "jss_lib_dir=$jss_lib_dir\n";
}

sub clean {
    our $class_dir;
    our $class_jar;
    our $jni_header_dir;

    print_do("rm -rf $class_dir");
    print_do("rm -f $class_jar");
    print_do("rm -rf $jni_header_dir");
}

sub build {
    our $dist_dir;

    #
    # generate MANIFEST.MF file in dist dir
    #
    my $manifest_file  = "$dist_dir/MANIFEST.MF";
    print "Creating $manifest_file\n";

    my $jss_revision   = `grep JSS_VERSION org/mozilla/jss/util/jssver.h`;
    chop($jss_revision);
    $jss_revision      = substr($jss_revision, 22, 3);
    my $build_revision = $jss_revision;
    my $append = 0;

    ensure_dir_exists($dist_dir);

    if ($append) {
        open(MYOUTFILE, ">>$manifest_file"); #open for write, append
    } else {
        open(MYOUTFILE, ">$manifest_file");  #open for write, overwrite
    }

    #*** Print freeform text, semicolon required ***
print MYOUTFILE <<"MyLabel";
Manifest-Version: 1.0
    
Name: org/mozilla/jss/
Specification-Title: Network Security Services for Java (JSS)
Specification-Version: $jss_revision
Specification-Vendor: Mozilla Foundation
Implementation-Title: org.mozilla.jss
Implementation-Version: $build_revision
Implementation-Vendor: Mozilla Foundation
MyLabel

    #*** Close the file ***
    close(MYOUTFILE);

    #
    # recursively find *.java
    #
    my %source_list;
    find sub {
        my $name = $File::Find::name;
        if( $name =~ /\.java$/) { 
            $source_list{$File::Find::name} = 1;
        }
    }, ".";

    #
    # weed out files that are excluded or don't need to be updated
    #
    my $file;
    our $class_dir;
    foreach $file (keys %source_list) {
        my $pattern;
        foreach $pattern (@excluded_sources) {
            if( $file =~ /$pattern/ ) {
                delete $source_list{$file};
            }
        }
        unless( java_source_needs_update( $file, $class_dir ) ){
            delete $source_list{$file};
        }
    }
    my @source_list = keys(%source_list);

    #
    # build the java sources
    #
    our $javac;
    our $javac_opt_flag;
    our $javac_deprecation_flag;
    our $classpath;
    our $jar;
    if( scalar(@source_list) > 0 ) {
        ensure_dir_exists($class_dir);
        print_do("$javac $javac_opt_flag $javac_deprecation_flag -sourcepath . -d $class_dir " .
            "$classpath " . join(" ",@source_list));
        print_do("sh -c 'cd $dist_dir/classes && $jar cvmf $dist_dir/MANIFEST.MF $dist_dir/xpclass.jar *'");
        print "Exit status was " . ($?>>8) . "\n";
    }

    #
    # create the JNI header files
    #
    our $jni_header_dir;
    our $javah;
    ensure_dir_exists($jni_header_dir);
    print_do("$javah -classpath $class_dir -d $jni_header_dir " .
        (join " ", @javah_classes) );
}

sub print_do {
    my $cmd = shift;
    print "$cmd\n";
    system($cmd);
    my $exit_status = $?>>8;
    $exit_status and die "Command failed ($exit_status)\n";
}

sub needs_update {
    my $target = shift;
    my @dependencies = @_;

    my $target_mtime = (stat($target))[9];
    my $dep;
    foreach $dep( @dependencies ) {
        my $dep_mtime = (stat($dep))[9];
        if( $dep_mtime > $target_mtime ) {
            return 1;
        }
    }
    return 0;
}

# A quick-and-dirty way to guess whether a .java file needs to be rebuilt.
# We merely look for a .class file of the same name. This won't work if
# the source file's directory is different from its package, and it
# doesn't know about nested or inner classes.
# source_file: the relative path to the source file ("org/mozilla/jss/...")
# dest_dir: the directory where classes are output ("../../dist/classes")
# Returns 1 if the source file is newer than the class file, or the class file
#   doesn't exist. Returns 0 if the class file is newer than the source file.
sub java_source_needs_update {
    my $source_file = shift;
    my $dest_dir = shift;

    my $class_dir = "$dest_dir/" . dirname($source_file);
    my $class_file = basename($source_file);
    $class_file =~ s/\.java/.class/;
    $class_file = $class_dir . "/" . $class_file;
    if( -f $class_file ) {
        my $class_stat = stat($class_file);
        my $source_stat = stat($source_file);

        if( $source_stat->mtime > $class_stat->mtime) {
            # class file exists and is out of date
            return 1;
        } else {
            #class file exists and is up to date
            return 0;
        }
    } else {
        # class file hasn't been generated yet.
        return 1;
    }
}

# Recursively makes the given directory. Dies at the first sign of trouble
sub ensure_dir_exists {
    my $dir = shift;
    my $parent = dirname($dir);
    if( $parent ne $dir ) {
        ensure_dir_exists($parent);
    }
    if( ! -d $dir ) {
        mkdir($dir, 0777) or die "Failed to mkdir $dir: $!";
    }
}

sub release {
    # copy all class files into release directory
    our $class_release_dir;
    our $class_dir;
    ensure_dir_exists("$class_release_dir");
    print_do("cp -r $class_dir/* $class_release_dir");
}

sub javadoc {
    our $dist_dir;
    our $javadoc;
    our $classpath;

    my $html_header_opt;
    if( $ENV{HTML_HEADER} ) {
        $html_header_opt = "-header '$ENV{HTML_HEADER}'";
    }

    ensure_dir_exists("$dist_dir/jssdoc");
    my $targets = join(" ", @packages);
    print "$targets\n";
    print_do("$javadoc -breakiterator $classpath -sourcepath . -d $dist_dir/jssdoc $html_header_opt $targets");
    print_do("cp $dist_dir/jssdoc/index.html $dist_dir/jssdoc/index.html.bak");
    print_do("cp $dist_dir/jssdoc/overview-summary.html $dist_dir/jssdoc/index.html");
}

sub test {
    our $os;
    our $dist_dir;

    our $jss_dir;
    our $jss_lib_dir;
    our $jss_objdir;

    our $nss_bin_dir;
    our $nss_lib_dir;

    if( $os eq 'Linux' || $os eq 'Darwin' ) {
        # Test JSS presuming that it has already been built

        if(( -d $dist_dir )  &&
           ( -d $jss_objdir || -l $jss_objdir )) {
            my $cmd = "cd $jss_dir/org/mozilla/jss/tests;"
                    . "perl all.pl dist \"$dist_dir\" \"$nss_bin_dir\" \"$nss_lib_dir\" \"$jss_lib_dir\";"
                    . "cd $jss_dir";

            print("#######################\n" .
                  "# BEGIN:  Testing JSS #\n" .
                  "#######################\n");
            print_do($cmd);
            print("#####################\n" .
                  "# END:  Testing JSS #\n" .
                  "#####################\n");
        } else {
            die "JSS builds are not available at $jss_objdir.";
        }
    } else {
        die "make test_jss is only available on Linux and MacOS platforms.";
    }
}
