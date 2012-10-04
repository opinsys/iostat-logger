#!/usr/bin/perl -w

use YAML;
use Data::Dumper;

@IOSTAT=`tail -n 13 /var/local/iostat.raw | grep -A13 avg`;
my ($stats);

open my $fh, '<', '/var/local/iostats' 
  or die "can't open config file: $!";

($stats) = YAML::LoadFile($fh);


my @titles;
my @values;
my %newstats;
my $cpu = 1;
my $disk = 0;
my $disks = {};
my @disktitles = ();
foreach my $row  ( @IOSTAT )
{
   chomp $row;
   if( $cpu && $row =~ /^avg-cpu/ ) {
       @titles = split(/\s+/, $row);
       shift @titles;
   }
   if( $cpu && $row =~ /^\s+[\d,\.\s]+$/ ) {
       @values = split(/\s+/, $row);
       shift @values;
       @newstats{@titles} = @values;
       foreach my $key ( keys %newstats ) {
           $newstats{$key} =~ s/,/./;
       }
       $cpu = 0;
       $disk = 1;
   }
   if( $disk && $row =~ /^\s*Device/ ) {
       @disktitles = split(/\s+/, $row);
       shift @disktitles;
   }

   if( $disk && $row =~ /^\s*(dm\-\d)/ ) {
       @newloads = split(/\s+/, $row);
       my $device = shift @newloads;
       my $i = 0;
       my $newloadstitles;
       foreach my $newload ( @newloads ) {
           $newload =~ s/,/./;
           $newloadstitles->{$disktitles[$i++]} = $newload;
       }
       
       $disks->{$device} = $newloadstitles;
#       print Dumper( $disks->{$device});
       
   }
}

my %newmaximums = map{ $_ => 0} @disktitles;

foreach my $disk (keys %$disks) {
    foreach my $diskstat (@disktitles) {
        my $cur_diskstat = $disks->{$disk}->{$diskstat};
        $newmaximums{$diskstat} = $cur_diskstat if $newmaximums{$diskstat} < $cur_diskstat;
    }
} 
    
foreach my $diskstat (@disktitles) {
   # print "diskstat: $diskstat\t";
   #print "Stats->diskstat: $stats->{$diskstat}, newmaximums->diskstat: $newmaximums{$diskstat}\n";
   if ($newmaximums{$diskstat} > $stats->{$diskstat}) {
      $newrec = 1;
      $stats->{$diskstat} = $newmaximums{$diskstat} 
   }
}
# print "maximums:" . Dumper( \%newmaximums );
$stats->{'idlecpu'} = 100 if (! defined $stats->{'idlecpu'}) || (! $stats->{'idlecpu'}) || $stats->{'idlecpu'} eq '~';

# print "newstats idle: " . $newstats{'%idle'} . "XXX\n";
if( $newstats{'%idle'} < $stats->{'idlecpu'} ) {
   $newrec = 1;
   $stats->{'idlecpu'} = $newstats{'%idle'} 
}
$stats->{'iowait'} = 0 if (! $stats->{'iowait'}) || $stats->{'iowait'} eq '~';

if( $newstats{'%iowait'} > $stats->{'iowait'} ) { 
    $newrec = 1;
    $stats->{'iowait'} = $newstats{'%iowait'} ;
}

open(IOSTATS,">/var/local/iostats");
print IOSTATS YAML::Dump($stats);
close(IOSTATS);
system('logger "IOSTAT report: '. join(",",YAML::Dump($stats)).'"') if $newrec;
print "IOSTAT report: ". join(",",YAML::Dump($stats));

