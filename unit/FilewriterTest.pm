package FilewriterTest;
use base qw(Test::Unit::TestCase);
use lib 'lib';
use Filewriter;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_filewrite {
    Filewriter::set_target_dir(".");
    Filewriter::writeTotal("this total");
    Filewriter::writeInconsis("this inconsisi");
    Filewriter::writeAll("this all");
}

1;


