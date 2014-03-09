# -*- mode: perl; coding: utf-8 -*-

package ComainuGetPath;

use strict;
use utf8;
use Config;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless $self, $class;
    return $self;
}

# adjust MS-Windows path -> "C:/xxx/yyy" style
sub adjust_winpath {
    my $self = shift;
    my ($path) = @_;
    if ($path !~ /^\//) {
        $path =~ s/\\/\//gs;
        return $path;
    }
    my $path_tmp = $path;
    open(STDERR2, ">&STDERR");
    close(STDERR);
    eval {
        if ($path_tmp =~ /^\/([a-zA-Z])\//) {
            # change drive letter "/c/" to "c:/"for msys
            $path_tmp =~ s/^\/([a-zA-Z])\//$1:\//;
        }
        # change drive letter "/" to "c:/cygwin/" for cygwin
        $path_tmp = qx(cygpath -am "$path_tmp");
        if (!$?) {
            # success of cygpath
            $path_tmp =~ s/\n.*//;
            $path = $path_tmp;
        } else {
            # failure of cygpath
            if ($path =~ /^\/([a-zA-Z])\//) {
                # change drive letter "/c/" to "c:/" for msys
                $path =~ s/^\/([a-zA-Z])\//$1:\//;
            } else {
                # in configuration by cygwin
                if ($path =~ /^\/cygdrive\/([a-zA-Z])\//) {
                    # change drive letter "/cygdrive/c/" to "c:/" for msys
                    $path =~ s/^\/cygdrive\/([a-zA-Z])\//$1:\//;
                } else {
                    # add drive letter "/c" for msys
                    $path = "c:/cygwin".$path;
                }
            }
        }
    };
    open(STDERR, ">&STDERR2");
    return $path;
}

sub get_mecab_dir_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        eval "require Win32::OLE";
        if (!$@) {
            if (my $ws = Win32::OLE->CreateObject("WScript.Shell")) {
                $path = $ws->RegRead("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\MeCab_is1\\InstallLocation");
                if ($path ne "") {
                    if ($path !~ /\\$/) {
                        $path .= "\\";
                    }
                    $path .= "bin";
                }
            }
        }
        $path = "C:\\Program Files\\MeCab\\bin"       if ! -d $path;
        $path = "C:\\Program Files (x86)\\MeCab\\bin" if ! -d $path;
        $path =~ s/\\/\//gs;
    }
    return $path;
}

sub get_mecab_dic_dir_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        eval "require Win32::OLE";
        if (!$@) {
            if (my $ws = Win32::OLE->CreateObject("WScript.Shell")) {
                $path = $ws->RegRead("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\MeCab_is1\\InstallLocation");
                if ($path ne "") {
                    $path .= "\\" if $path !~ /\\$/;
                    $path .= "dic";
                }

                if (!-d $path) {
                    $path = $ws->RegRead("HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\unidic_win\\InstallLocation");
                    if ($path ne "") {
                        $path .= "\\" if $path !~ /\\$/;
                        $path .= "dic";
                    }
                }
            }
        }
        $path = "C:\\Program Files\\unidic\\dic"       if !-d $path;
        $path = "C:\\Program Files (x86)\\unidic\\dic" if !-d $path;
        $path = "C:\\Program Files\\MeCab\\dic"        if !-d $path;
        $path = "C:\\Program Files (x86)\\MeCab\\dic"  if !-d $path;

        $path =~ s/\\/\//gs;
    }
    return $path;
}

sub get_unidic_db_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        $path = "C:\\Program Files\\unidic2\\share\\unidic.db"       if !-f $path;
        $path = "C:\\Program Files (x86)\\unidic2\\share\\unidic.db" if !-f $path;
        $path = "C:\\unidic2\\share\\unidic.db"                      if !-f $path;

        $path =~ s/\\/\//gs;
    }
    return $path;
}

sub get_yamcha_dir_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        $path = "C:/Program Files/yamcha-0.33/bin";
        $path = "C:/Program Files (x86)/yamcha-0.33/bin" if !-d $path;
        $path = "C:/yamcha-0.33/bin" if !-d $path;
    }
    return $path;
}

sub get_svm_tool_dir_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        $path = "C:/Program Files/TinySVM-0.09/bin";
        $path = "C:/TinySVM-0.09/bin" if !-d $path;
        $path = "C:/Program Files (x86)/TinySVM-0.09/bin" if !-d $path;
    }
    return $path;
}

sub get_crf_dir_auto {
    my $self = shift;
    my $path = "";
    if($Config{"osname"} eq "MSWin32") {
        for ( (0.58, 0.57, 0.56, 0.55, 0.54) ) {
            $path = 'C:/Program Files/CRF++-' . $_;
            last if -d $path;
            $path = 'C:/Program Files (x86)/CRF++-' . $_;
            last if -d $path;
            $path = 'C:/CRF++-' . $_;
            last if -d $path;
        }
        $path = 'C:/Program Files (x86)/CRF++-0.58' if -d $path;
    }
    return $path;
}

sub get_java_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        $path = $ENV{"JAVA_HOME"}."/bin/java.exe";
        if (!-f $path) {
            ($path) = (
                glob("C:/jdk*/bin/java.exe"),
                glob("C:/Program Files/Java/jdk*/bin/java.exe"),
                glob("C:/Program Files/Java/jre*/bin/java.exe"),
                glob("C:/Program Files (x86)/Java/jdk*/bin/java.exe"),
                glob("C:/Program Files (x86)/Java/jre*/bin/java.exe"),
            );
        }
    }
    return $path;
}

sub get_mstparser_dir_auto {
    my $self = shift;
    my $path = "";
    if ($Config{"osname"} eq "MSWin32") {
        $path = "C:/mstparser";
        ($path) = glob("C:/mstparser*") if !-f $path;
        $path = "mstparser" if !-f $path;
    }
    return $path;
}

1;
#################### end of file ####################
