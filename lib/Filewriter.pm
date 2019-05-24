package Filewriter;

use strict;
use File::Spec::Functions 'catfile';

my $total_sql_filepath;
my $total_sql_file;

my $inconsistent_sql_filepath;
my $inconsistent_sql_file;

my $gen_data_phase = 1;

sub set_target_dir {
    my $target_dir = @_[0];
    $total_sql_filepath = catfile($target_dir, "total.sql");
    $inconsistent_sql_filepath = catfile($target_dir, "inconsis.sql");
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
        lock $total_sql_filepath;
        unless(defined $total_sql_file){
            open $total_sql_file, ">".$total_sql_filepath;
        }
    }
}

sub writeTotal {
    createTotal();
    my $content = @_[0];

    print $total_sql_file "$content;\n";
}

sub createInconsis {
    unless(defined $inconsistent_sql_file){
        lock $inconsistent_sql_filepath;
        unless(defined $inconsistent_sql_file){
            open $inconsistent_sql_file, ">".$inconsistent_sql_filepath;
        }
    }
}

sub writeInconsis {
    createInconsis();

    my $content = @_[0];

    print $inconsistent_sql_file "$content;\n";
}

sub writeAll {
    my $content = @_[0];
    writeTotal($content);
    writeInconsis($content);
}

1;