package Filewriter;

use strict;
use File::Spec::Functions 'catfile';

use Fcntl qw(:flock SEEK_END);

my $total_sql_filepath;
my $total_sql_file;

my $inconsistent_sql_filepath;
my $inconsistent_sql_file;

my $ddl_sql_filepath;
my $ddl_sql_file;

my $gen_data_phase = 1;


sub lock {
    my ($fh) = @_;
    flock($fh, LOCK_EX) or die "Cannot lock mailbox - $!\n";
    # and, in case someone appended while we were waiting...
    seek($fh, 0, SEEK_END) or die "Cannot seek - $!\n";
}

sub unlock {
    my ($fh) = @_;
    flock($fh, LOCK_UN) or die "Cannot unlock mailbox - $!\n";
}

sub set_target_dir {
    my $target_dir = @_[0];
    $total_sql_filepath = catfile($target_dir, "total.sql");
    $inconsistent_sql_filepath = catfile($target_dir, "inconsis.sql");
    $ddl_sql_filepath = catfile($target_dir, "ddl.sql");
}

sub is_need_write {
    return defined $total_sql_filepath;
}

sub is_gen_data(){
    return $gen_data_phase;
}

sub close_gen_data(){
    $gen_data_phase = 0;
}

sub createTotal {
    unless(defined $total_sql_file){
        open $total_sql_file, ">".$total_sql_filepath;
    }
}

sub writeTotal {
    createTotal();
    my $content = @_[0];
   
    lock($total_sql_file);
    print $total_sql_file "$content;\n";
    unlock($total_sql_file)
}

sub createInconsis {
    unless(defined $inconsistent_sql_file){
        open $inconsistent_sql_file, ">".$inconsistent_sql_filepath;
    }
}

sub writeInconsis {
    createInconsis();

    my $content = @_[0];

    lock($inconsistent_sql_file);
    print $inconsistent_sql_file "$content;\n";
    unlock($inconsistent_sql_file)
}

sub writeAll {
    my $content = @_[0];
    writeTotal($content);
    writeInconsis($content);
}

sub createDDL {
    unless(defined $ddl_sql_file){
        unless(defined $ddl_sql_file){
            open $ddl_sql_file, ">".$ddl_sql_filepath;
        }
    }
}

sub writeDDL {
    createDDL();

    my $content = @_[0];

    print $ddl_sql_file "$content;\n";
}

1;