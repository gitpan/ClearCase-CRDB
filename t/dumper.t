# Automatically generates an ok/nok msg, incrementing the test number.
BEGIN {
   my($next, @msgs);
   sub printok {
      push @msgs, ($_[0] ? '' : 'not ') . "ok @{[++$next]}\n";
      return !$_[0];
   }
   END {
      print "\n1..", scalar @msgs, "\n", @msgs;
   }
}

my $final = 0;

require ClearCase::CRDB::Dumper;
$final += printok(1);
exit $final if $final;

if (system "cleartool pwd -h 2>&1") {
    print STDERR qq(

******************************************************************
ClearCase::CRDB is only useable if ClearCase is installed. It was
unable to find ClearCase so will not continue the test.  You may
be able to work around this by modifying your PATH appropriately.
******************************************************************

);
    exit 0;
}

#open(ERR, '>&STDERR');
open(STDERR, ">&STDOUT");
chdir('./t') || chdir('../t') || die "./t: $!";

$final += printok(!system("clearmake -C gnu"));
exit $final if $final;
unlink '.cmake.state';

my $tgt = 'prog1';

# Test direct analysis from CR ...
$final += printok(!system("$^X -Mblib ../whouses -do $tgt -r -b $tgt"));
exit $final if $final;

my $cr = ClearCase::CRDB::Dumper->new;
$cr->crdo($tgt);
$cr->catcr;
$final += printok(%$cr);	# assume a non-empty hash is good news

$cr->store("$tgt.crdb");
$final += printok(-e "$tgt.crdb");

# Test analysis from cached CR DB ...
$final += printok(!system("$^X -Mblib ../whouses -db $tgt -fmt Dumper -r -b $tgt"));
exit $final if $final;

#print ERR "A sample of the CRDB format has been left in t/prog1.crdb ...\n";

exit $final;
