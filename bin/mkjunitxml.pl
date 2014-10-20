#!/usr/bin/perl

use strict;
use warnings;

my @TESTCASES=();
my $lastline=undef;
my $date;
my $time;
my $out;

my $oldseconds=undef;
my $script=undef;
my $testcase=undef;
my $testname=undef;
my $testresult=undef;
my $teststarttime=undef;
my $testendtime=undef;
my $testfailure=undef;
my $system_out="";
my $host=`hostname`;
chomp ($host);

sub testcase
{	my ($testcase,$testname,$testresult,$script,
           $system_out,$teststarttime,$testendtime,
           $testfailure)=@_;

	my $time=($testendtime-$teststarttime)+1;
	my $result="<testcase classname=\"$script\" name=\"$testcase $testname\" time=\"$time\">\n";
		
	$system_out=~s/\&/\&amp;/g;
	$system_out=~s/</\&lt;/g;
	$system_out=~s/>/\&gt;/g;
	
	if ($testfailure ne "") {
		$result.="<failure>\n$testfailure</failure>\n";
	}
	$result.="<system-out>\n$system_out</system-out>\n";
	$result .= "</testcase>\n";
	push @TESTCASES,$result;
}

sub processline
{	my ($date,$time,$out,$line)=@_;
	if ($time !~ /^(..):(..):(..)$/) {
		die "$time: illegal time format, stopped";
	}
	my ($h,$m,$s)=($1,$2,$3);
	my $seconds=3600*$h+60*$m+$s;
	$oldseconds=$seconds unless defined($oldseconds);
	$seconds-=$oldseconds;
	if ($seconds<0) {
		$seconds+=86400;
	}
	
	if ($line=~/^TM info: Running script (\S+)/) {
		$script=$1;
		$system_out .= "$out: $line";
		return;
	}
	$system_out .= "$out: $line";
	if ($line=~/^##### Test Case Start: (\S+)\s*(.*)/) {
		($testcase,$testname)=($1,$2);
		$system_out = "$out: $line"; # reset system out
		$teststarttime=$seconds;
		return;
	}
	if ($line=~/^##### Test Case End: (\S+)\s*(\S+)/) {
		die "no test case, stopped"
			unless defined($testcase);
		die "test case mismatch: $testcase - $1, stopped"
			unless $testcase eq $1;
		$testresult=$2;
		$testfailure="";
		$testfailure="$script: $testcase - $testresult" if $testresult ne "PASSED";
		$testendtime=$seconds;

		testcase($testcase,$testname,$testresult,$script,
                         $system_out,$teststarttime,$testendtime,
                         $testfailure);
			 
		$testcase=undef;
		$system_out = "";
	}
}

sub processend
{	die if defined($testcase);
}

my ($newdate,$newtime,$newout,$newlastline);
while (<>) {
	next if /^auto_path/;
	if (/^(\S+)\s+(\S+)\s+(\S+):\s+(.*)/) {
		($newdate,$newtime,$newout,$newlastline)=($1,$2,$3,$4);
		$newlastline.="\n";
		processline($date,$time,$out,$lastline) if defined($lastline);
		($date,$time,$out,$lastline)=($newdate,$newtime,$newout,$newlastline);
		
	} else {
		$lastline .= $_;
	}
}
processline($date,$time,$out,$lastline) if defined($lastline);
processend();

print "<?xml version=\"1.0\"?>\n";
print "<testsuites>\n";
#print "<testsuite errors=\"0\" failures=\"1\" hostname=\"host\" name=\"testname\" tests=\"1\" time=\"0\" timestamp=\"2007-11-02T23:13:50\">\n";
print "<testsuite name=\"FSMJENKINS\" hostname=\"$host\">\n";
for my $testcase (@TESTCASES) {
	print $testcase;
}
print "</testsuite>\n";
print "</testsuites>\n";
