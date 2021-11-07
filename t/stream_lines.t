use strict;
use warnings;
use Test::More;
use IO::Pipely 'pipely';
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;

subtest 'Basic line buffering' => sub {
  my ($read, $write) = pipely or die "Failed to open pipe: $!";

  my @lines;
  my $reader = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($read)->watch_lines;
  $reader->on(read_line => sub {
    my ($reader, $line, $sep) = @_;
    push @lines, [$line, $sep];
  });
  $reader->on(read => sub { Mojo::IOLoop->stop });
  $reader->start;

  my $writer = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($write);
  $writer->start;

  $writer->write('foo');

  my $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [], 'no lines received';
  @lines = ();

  $writer->write("bar\x0Abaz");

  $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['foobar', "\x0A"]], 'one line received';
  @lines = ();

  $writer->write_line('line?');

  $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['bazline?', "\x0D\x0A"]], 'one line received';
};

subtest 'Custom line separators' => sub {
  my ($read, $write) = pipely or die "Failed to open pipe: $!";

  my @lines;
  my $reader = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($read)->watch_lines;
  $reader->on(read_line => sub {
    my ($reader, $line, $sep) = @_;
    push @lines, [$line, $sep];
  });
  $reader->on(read => sub { Mojo::IOLoop->stop });
  $reader->start;

  my $writer = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($write);
  $writer->start;

  $reader->read_line_separator('bar');
  $writer->write_line_separator('bar');
  $writer->write_line("foobar\x0Abarbaz");

  my $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['foo', 'bar'],["\x0A",'bar'],['baz','bar']], 'three lines received';
};

subtest 'Multiple lines on close' => sub {
  my ($read, $write) = pipely or die "Failed to open pipe: $!";

  my @lines;
  my $reader = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($read)->watch_lines;
  $reader->on(read_line => sub {
    my ($reader, $line, $sep) = @_;
    push @lines, [$line, $sep];
  });
  $reader->on(read => sub { Mojo::IOLoop->stop });
  $reader->start;

  my $writer = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($write);
  $writer->start;

  $reader->read_line_separator('1');
  $reader->on(read => sub { shift->read_line_separator('2')->close; $writer->close });
  $writer->write('before1mid2after');

  my $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['before', '1'], ['mid', '2'], ['after', undef]], 'remaining lines and bytes received';
};

subtest 'Line separator on close' => sub {
  my ($read, $write) = pipely or die "Failed to open pipe: $!";

  my @lines;
  my $reader = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($read)->watch_lines;
  $reader->on(read_line => sub {
    my ($reader, $line, $sep) = @_;
    push @lines, [$line, $sep];
  });
  $reader->on(read => sub { Mojo::IOLoop->stop });
  $reader->start;

  my $writer = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($write);
  $writer->start;

  $reader->on(read => sub { shift->read_line_separator('3')->close; $writer->close });
  $writer->write('bar3');

  my $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['bar', '3']], 'remaining line received';
};

subtest 'No line separator on close' => sub {
  my ($read, $write) = pipely or die "Failed to open pipe: $!";

  my @lines;
  my $reader = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($read)->watch_lines;
  $reader->on(read_line => sub {
    my ($reader, $line, $sep) = @_;
    push @lines, [$line, $sep];
  });
  $reader->on(read => sub { Mojo::IOLoop->stop });
  $reader->start;

  my $writer = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($write);
  $writer->start;

  $reader->on(read => sub { shift->read_line_separator('4')->close; $writer->close });
  $writer->write('bar');

  my $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['bar', undef]], 'remaining bytes received';
};

subtest 'Closing stream in read_line event' => sub {
  my ($read, $write) = pipely or die "Failed to open pipe: $!";

  my @lines;
  my $reader = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($read)->watch_lines;
  $reader->on(read_line => sub {
    my ($reader, $line, $sep) = @_;
    push @lines, [$line, $sep];
    $reader->close;
  });
  $reader->on(read => sub { Mojo::IOLoop->stop });
  $reader->start;

  my $writer = Mojo::IOLoop::Stream->with_roles('+LineBuffer')->new($write);
  $writer->start;

  $writer->write_line('foo');

  my $timeout = Mojo::IOLoop->timer(0.1 => sub { Mojo::IOLoop->stop });
  Mojo::IOLoop->start;
  Mojo::IOLoop->remove($timeout);

  is_deeply \@lines, [['foo', "\x0D\x0A"]], 'one line received';
};

done_testing;
