#!/usr/bin/perl

use strict;
use warnings;

use Net::Twitter;
use Template;
use YAML 'LoadFile';

my $config = LoadFile(shift || 'config.yaml');

my $t = Net::Twitter->new({
  traits => [qw(API::RESTv1_1 OAuth)],
  consumer_key => $config->{consumer_key},
  consumer_secret => $config->{consumer_secret},
}) or die;

my ($access_token, $access_token_secret) = retrieve_tokens();

if ($access_token && $access_token_secret) {
  $t->access_token($access_token);
  $t->access_token_secret($access_token_secret);
}

unless ($t->authorized()) {
  get_twitter_authorization();
  exit();
}

my $list_members;
my $cursor = -1;

while ($cursor) {
  my $members = $t->list_members({
    owner_screen_name => 'balhamtwits',
    slug => 'balhamites',
    cursor => $cursor,
  });

  $cursor = $members->{next_cursor};
  push @$list_members, @{$members->{users}};
}

my $tweets = $t->list_statuses({
  owner_screen_name => 'balhamtwits',
  slug => 'balhamites',
});

my $tt = Template->new;
$tt->process('index.tt',
             { tweets => $tweets, cfg => $config, follows => $list_members },
             'index.html',
             {binmode => ':utf8'})
  or die $tt->error;

sub get_twitter_authorization {
  print "Visit the following URL in your browser to authorize this app:\n" .
    $t->get_authorization_url() . "\n";
  print "Once done, enter the PIN# ";
    
  my $pin = <STDIN>; # wait for user input
  chomp $pin;

  eval {
    print "PIN received, contacting twitter to obtain access tokens...\n";
    my ($access_token, $access_token_secret, $user_id, $screen_name) =
      $t->request_access_token(verifier => $pin);

    if ($access_token && $access_token_secret) {
      print "Tokens received, storing to .tokens...\n";
      store_tokens($access_token, $access_token_secret);
      print "Done. Please run program again.\n";
    } else {
      print "Twitter error: did not receive access tokens.\n";
    }
  };

  if (my $err = $@) {
    die "Twitter error: ", $err->error(), "\n";
  }
}

sub retrieve_tokens {
  if (-e '.tokens') {
    open my $tok, '<', '.tokens'
      or die ".tokens: $!\n";

    chomp(my $token = <$tok>);
    chomp(my $secret = <$tok>);

    return ($token, $secret);
  }

  return;
}

sub store_tokens {
  my ($a_token, $a_token_secret) = @_;

  open my $tok, '>', '.tokens' or
    die ".tokens: $!\n";

  print $tok $a_token, "\n";
  print $tok $a_token_secret, "\n";
}
