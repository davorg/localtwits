#!/usr/bin/perl

use strict;
use warnings;

use Net::Twitter;
use Template;
use YAML 'LoadFile';

my $config = LoadFile(shift || 'config.yaml');

my $t = Net::Twitter->new({
  username => $config->{username},
  password => $config->{password},
}) or die;

my $follows = autofollow($t);

my $tweets = $t->friends_timeline({count => $config->{tweets} || 20});

my $tt = Template->new;
$tt->process('index.tt',
             { tweets => $tweets, follows => $follows, cfg => $config, },
             'index.html',
             {binmode => ':utf8'})
  or die $tt->error;

sub autofollow {
  my $t = shift;

  my %follow;
  my $follow = $t->friends;

  unless ($follow) {
    warn "$t->http_message\n";
    return;
  }

  foreach (@$follow) {
    $follow{$_->{screen_name}} = 1;
  }

  my %nofollow;
  if (-e 'nofollow') {
    open my $nf, '<', 'nofollow' or die $!;
    while (<$nf>) {
      chomp;
      $nofollow{$_} = 1;

      if ($follow{$_}) {
        $t->destroy_friend($_);
        delete $follow{$_};
      }
    }
  }

  if (defined(my $f = $t->followers)) {
    foreach (@{$f}) {
      unless ($nofollow{$_->{screen_name}} or $follow{$_->{screen_name}}) {
        $t->create_friend($_->{screen_name});
      }
    }
  }

  return \%follow;
}
