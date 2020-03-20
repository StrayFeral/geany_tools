#!/usr/bin/perl

# IMPORT GEANY PROJECT
# by Evgueni.Antonov@gmail.com
# 2020-03-17

# WHAT IS THIS ?
# This is a simple Perl script to import Geany project files from a
# remote machine, to a local machine.

# NOTE: I wrote this entirely for my own personal need. If you are
# in a similar situation, you might find this useful. Otherwise,
# I don't think many people will need this script.

# WHY IS THIS NEEDED ?
# I use Geany on different machines and I need the project files copied
# back and forth between the different machines. This is not very
# convenient by default.

# WHAT PROJECT FILES ?
# I mean the default way Geany handle projects and NOT any of the
# Geany project handling extensions !!!
#
# When you first install Geany, by default it saves any projects you
# create into files with .geany extension. These files by default are
# saved into your home directory, subdirectory 'projects' or said
# simply:
# /home/<YOURUSERNAME>/projects
# where for each project is created a subdirectory with the name of
# the project and a filename with the project name is created. So if
# your project name is 'MyProject1' and your username is 'john',
# then Geany creates:
# /home/john/projects/MyProject1/
# /home/john/projects/MyProject1.geany
#
# If you use any of the Geany project management extensions, this
# script probably won't be useful to you at all.

# WHAT IS THE IDEA HERE ?
# MY USE CASE:
# I have an office machine with few mount points. Local file system
# hosts my Geany project files. The actual code sources are located
# spread on the different mounted file systems.
#
# The mounted filesystems are all virtual servers.
#
# I also have a home machine, connected trough VPN to the office
# network. For convenience, I have created the same mountpoints on my
# home machine. I however use a TODO.txt file, serving as digital notes.
# I copy this file over to the local machine, so I don't depend on my
# office machine, in case somebody reboot it or disconnect it
# (long story, we are in the COVID-19 time now, no idea what will
# happen in the office, but I know - nobody will shut-down the virtual
# servers...).
#
# So in short: I work in the office on a certain project, but then
# on the next day I may work from home and I want to use Geany and
# pick-up the project from where I left it off in the office, so I
# connect to my office desktop and copy the file over to my home
# computer. Cool, but some things are different now. I used to
# manually edit the file, but as I use multiple project files, now this
# is a long edit.
#
# Also on the next day I may go back to the office and pick-up the
# project where I left it off at home. So the day before, I upload
# the project file to my office desktop. Again - some manual editing.
#
# You understand I got real bored of editing project files, before I
# actually start working. So I created this script, to help me automate
# the home<->office migration procedure.
#
# Just in case, as somebody might have different mount points, for
# convenience I put here a hash, holding anything, which might be
# different on the remote project file, with anything to be replaced
# with on the local project file.


# NOTE: YOU NEED TO EDIT THE SETUP SECTION BELOW (LINE 214)



use strict;
use warnings;
use File::Copy;




sub __slash_to_2f {
    my $s                       = shift;
    $s                          =~ s@/@%2F@g;
    return $s;
}


sub __2f_to_slash {
    my $s                       = shift;
    $s                          =~ s@%2F@/@g;
    return $s;
}


sub __check_mount_point {
    my $s                       = shift;
    my $result                  = `mount | grep $s`;
    die("No mount point '$s'") if (!$result);
}


sub __ls {
    my ($s, $dir)               = @_;
    print("* LISTING PROJECT FILES IN ($s): $dir\n");
    
    opendir(my $dh, $dir) or die("Cannot open directory ($dir) for reading.");
    
    my @dirlist;
    while (my $fn = readdir($dh)) {
        push(@dirlist, $fn) if ($fn =~ /\.geany$/ and (-f $fn));
    }
    
    closedir($dh);
    
    my $total                   = scalar(@dirlist);
    
    my $i                       = 0;
    foreach my $fn (sort(@dirlist)) {
        $i++;
        print(sprintf("    [%03i/%03i] $fn\n", $i, $total));
    }
    
    print("\nDONE.\n\n");
    exit(0);
}


sub __create_backup {
    my ($dir, $backup_dir_name) = @_;
    print("* CREATING BACKUP COPIES OF THE PROJECT FILES IN: $backup_dir_name\n");
    
    opendir(my $dh, $dir) or die("Cannot open directory ($dir) for reading.");
    
    my @dirlist;
    while (my $fn = readdir($dh)) {
        push(@dirlist, $fn) if ($fn =~ /\.geany$/ and (-f $fn));
    }
    
    closedir($dh);
    
    my $total                   = scalar(@dirlist);
    
    if (!-d $backup_dir_name) {
        print("* Creating backup directory: $backup_dir_name ... ");
        mkdir($backup_dir_name) or die ("Cannot create backup directory ($backup_dir_name).");
        print("Done.\n");
    }
    
    my $i                       = 0;
    foreach my $fn (sort(@dirlist)) {
        $i++;
        print(sprintf("    [%03i/%03i] $fn\n", $i, $total));
        copy("$dir/$fn", "$backup_dir_name/$fn") or die("Cannot make backup file: $!")
    }
    
    print("\nDONE.\n\n");
    exit(0);
}


# While a file may contain mixed line endings, we will get only the dominant one
# Code by PerlMonks user graff 2015 (no idea of his real name)
# Thanks.
sub __get_eol {
    my $s                       = shift;
    my ($cr, $lf, $crlf)        = (0)x3;
     
    unless (open(I, $s)) {
        warn("Cannot open $s: $!\n");
        next;
    }
    
    binmode I;
    $_                          = " ";
     
    while (read(I, $_, 65536, 1)) {
        $lf                     += tr/\x0a/\x0a/;
        $cr                     += tr/\x0d/\x0d/;
        $crlf                   += s/\x0d\x0a/xx/g ;
        $_                      = chop;
        $cr-- if ( $_ eq "\x0d" ); # a final CR or LF will get counted
        $lf-- if ( $_ eq "\x0a" ); # again on the next iteration
    }
    
    $cr++ if ($_ eq "\x0d");
    $lf++ if ($_ eq "\x0a");
    #print("$s: $cr CR, $lf LF, $crlf CRLF\n");
    
    # Original 2015 code ended with the print line. But I need it as a
    # function, so I dropped these lines too (2020)
    my $eols                    = {
        $cr                     => "\r",
        $lf                     => "\n",
        $crlf                   => "\r\n",
    };
    my @sorted                  = reverse(sort(keys(%{$eols})));
    
    return $eols->{shift(@sorted)};
}



# --- SETUP BEGIN (edit only this section)

# Geany project paths
my $remote_mountpoint           = '/mnt/YOUROFFICECOMPUTER'; # Which machine we will export from
my $local_path                  = '/home/YOURUSERNAME/projects'; # Where to import to
my $remote_path                 = $remote_mountpoint.'/home/YOURUSERNAME/projects'; # Where to export from
my $backup_path                 = "$local_path/backup"; # Local backup path
my $last_dir                    = undef; # KEEP UNDEF IF YOU DON'T WANT TO CHANGE THIS IN THE PROJECT FILE

# If you don't have anything like my notes file, just leave these empty.
# Yes, I know - Geany have a scratch-pad and also parses for any TODO/FIXME
# strings, but I always keep additional notes file...
#
# NOTE: These won't be copied by this script - in fear of overwrite or
# just maintainint local ones...
my $remote_notes                = '/home/YOURUSERNAME/Documents/TODO.txt';
my $local_notes                 = '/home/YOURUSERNAME/projects/ANOTHERDIRECTORY/TODO.txt';

# Various files/paths to look for and replace with...
my $search_and_replace          = {
    # FORMAT: 'string to search for' => 'string to replace with',
    $remote_notes               => $local_notes,
    $remote_path                => $local_path, # Just in case (no idea if you have different mount points on both machines
    # replace_this              => with_that,
    # replace_something         => with_something_else,
    # ...
};

# --- SETUP END






# MAIN BEGIN
eval {
    print("\n***IMPORT GEANY PROJECT***   by Evgueni.Antonov, 2020-03-17\n");
    print("USAGE: import_geany_project.pl [REMOTEPATH]<PROJECTFILE>[.geany] nocopy\nOR   : import_geany_project.pl <LSLOCAL|LSREMOTE>\nOR   : import_geany_project.pl <DOBACKUP>\nThe 'nocopy' parameter is when you already copied the project file locally.\nThe 'lsremote' or 'lslocal' parameters just do ls on the local or remote path. For convenience.\n\n");
    
    my $filename                = $ARGV[0];
    die("No project file to import.") if (!$filename);
    exit(0) if ($filename =~ /^[-]*help$/i);
    
    # We really don't care the value here
    my $nocopy                  = $ARGV[1];
    if (!defined($nocopy)) {
        $nocopy                 = 0;
    } else {
        $nocopy                 = 1;
    }
    
    $filename                   .= '.geany' if ($filename !~ m@\.geany$@);
    my $remote_file             = "$remote_path/$filename" if ($filename !~ m@/@);
    $remote_file                = "$local_path/$filename" if ($nocopy and $filename !~ m@/@);
    my $project_name            = $filename;
    $project_name               =~ s/\.geany$//;
    
    while ($filename =~ m@/@) {
        $filename               = substr($filename, 1);
    }
    my $local_file              = "$local_path/$filename";
    
    __check_mount_point($remote_mountpoint) if (!$nocopy and $filename !~ /^dobackup/i);
    
    __ls('remote path', $remote_path) if ($filename =~ /^lsrem/i);
    __ls('local path', $local_path) if ($filename =~ /^lsloc/i);
    __create_backup($local_path, $backup_path) if  ($filename =~ /^dobackup/i);
    
    print("* Importing: $remote_file --> $local_file\n\n");
    die("File not found.") if (!-e $remote_file);
    die("File not a plain file.") if (!-f $remote_file);
    
    print("\n*** NOTE: We will not copy anything, as the nocopy parameter is passed.\n\n") if ($nocopy);
    
    if (!-d "$local_path/$project_name") {
        print("* Creating local project directory: $local_path/$project_name\n");
        mkdir("$local_path/$project_name") or die("Cannot create project directory.");
    } else {
        print("Local project directory already exists.\n");
    }
    
    copy($remote_file, $local_file) or die("Cannot import file: $!") if (!$nocopy);
    
    # Detecting the EOL chars
    my $eol                     = __get_eol($local_file);
    
    print("* Reading file ... ");
    open(my $fh, "<:encoding(utf8)", $local_file) or die("Cannot open local file for reading.");
    chomp(my @fbuf                    = <$fh>); # No stripping of EOL chars - we want to keep them as is
    close($fh);
    print(scalar(@fbuf) . " line(s)\n");
    
    print("* Processing lines ...\n");
    foreach (my $i = 0; $i < scalar(@fbuf); $i++) {
        my $line                = $fbuf[$i];
        
        if ($line =~ /^base_path=/) {
            $line               = "base_path=$local_path/$project_name/";
        }
        
        if ($line =~ /^last_dir=/ and defined($last_dir)) {
            $line               = "last_dir=$last_dir";
        }
        
        # We really don't need this. It's just in case...
        if ($line =~ /^name=/) {
            $line               =~ /^name=(.*?)$/;
            my $file_project    = $1;
            print("\n*** WARNING: The given project name ($project_name) does not match the project name in the file ($file_project). This script will not modify it.\n\n") if ($project_name ne $file_project);
        }
        
        if ($line =~ /^FILE_NAME_\d+=/) {
            $line               =~ /^FILE_NAME_(\d+)=(.*?)$/;
            my $num             = $1;
            my $properties      = $2;
            
            my @props           = split(/;/, $properties);
            my $file            = $props[7];
            
            $file               = __2f_to_slash($file);
            
            foreach my $searchfor (keys(%{$search_and_replace})) {
                my $replacewith = $search_and_replace->{$searchfor};
                $file           =~ s@$searchfor@$replacewith@;
            }
            
            $file               = __slash_to_2f($file);
                        
            $props[7]           = $file;
            chomp($props[-1]); # Some issue appeared here, so we do it manually
            $properties         = join(';', @props);
            $line               = "FILE_NAME_$num=$properties";
        }
        
        $fbuf[$i]               = $line;
    }
    
    print("* Writing file\n");
    open($fh, ">:encoding(utf8)", $local_file) or die("Cannot open local file for writing.");
    print($fh join($eol, @fbuf));
    close($fh);
    
    print("\n*** REMINDER: The notes file has not been copied. You might want to do it yourself:\ncp $remote_notes $local_notes\n") if (!$nocopy and defined($remote_notes) and $remote_notes ne '');
    
    print("\nDONE.\n\n");
    1;
} or do {
    my $exp                     = $@ || 'Unknown exception.';
    
    print("=============================[ EXCEPTION CAUGHT:\n");
    print("$exp\n");
};
