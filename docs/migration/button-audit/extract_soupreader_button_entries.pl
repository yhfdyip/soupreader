#!/usr/bin/env perl
use strict;
use warnings;
use File::Find;

my $root = 'lib';
my @dart_files;

find(
  {
    wanted => sub {
      return unless -f $_;
      return unless /\.dart$/;
      my $path = $File::Find::name;
      return
        unless $path eq 'lib/main.dart'
        || $path =~ m{^lib/features/.+/(views|widgets)/.+\.dart$};
      push @dart_files, $path;
    },
    no_chdir => 1,
  },
  $root,
);

@dart_files = sort @dart_files;

my @targets = (
  [qr/CupertinoActionSheetAction\s*\(/, 'CupertinoActionSheetAction'],
  [qr/CupertinoButton(?:\.filled)?\s*\(/, 'CupertinoButton'],
  [qr/IconButton\s*\(/, 'IconButton'],
  [qr/PopupMenuButton\s*</, 'PopupMenuButton'],
  [qr/PopupMenuItem\s*</, 'PopupMenuItem'],
  [qr/CupertinoContextMenuAction\s*\(/, 'CupertinoContextMenuAction'],
  [qr/ListTile\s*\(/, 'ListTile'],
  [qr/CupertinoListTile(?:\.notched)?\s*\(/, 'CupertinoListTile'],
  [qr/ShadButton\s*\(/, 'ShadButton'],
  [qr/ShadIconButton\s*\(/, 'ShadIconButton'],
  [qr/SettingsNavItem\s*\(/, 'SettingsNavItem'],
  [qr/SettingsActionItem\s*\(/, 'SettingsActionItem'],
  [qr/SettingsToggleItem\s*\(/, 'SettingsToggleItem'],
  [qr/SettingsSelectItem\s*\(/, 'SettingsSelectItem'],
  [qr/SettingsSliderItem\s*\(/, 'SettingsSliderItem'],
  [qr/ReaderLegacyMenuHelper\.buildReadMenuActions\s*\(/,
    'ReaderLegacyMenuActions'],
);

print join(
  "\t",
  qw(
    seq module page file line widget_kind label trigger snippet
  )
), "\n";

my $seq = 0;
for my $file (@dart_files) {
  open my $fh, '<', $file or die "open $file failed: $!";
  my @lines = <$fh>;
  close $fh;

  for (my $i = 0; $i <= $#lines; $i++) {
    my $line = $lines[$i];
    for my $target (@targets) {
      my ($pattern, $widget_kind) = @$target;
      next unless $line =~ $pattern;

      my ($block, $end_idx) = _capture_block(\@lines, $i);
      my $label = _extract_label($block);
      my $trigger = _extract_trigger($block, $widget_kind);
      my $snippet = _build_snippet($line);
      my $module = _extract_module($file);
      my $page = _extract_page($file);

      $seq++;
      print join(
        "\t",
        $seq,
        $module,
        $page,
        $file,
        $i + 1,
        $widget_kind,
        $label,
        $trigger,
        $snippet,
      ), "\n";

      $i = $end_idx if $end_idx > $i;
      last;
    }
  }
}

sub _capture_block {
  my ($lines_ref, $start_idx) = @_;
  my @lines = @{$lines_ref};
  my $max_idx = $#lines;
  my $end_idx = $start_idx;
  my $depth = 0;
  my $started = 0;
  my $limit = $start_idx + 90;
  $limit = $max_idx if $limit > $max_idx;
  my $block = '';

  for my $idx ($start_idx .. $limit) {
    my $ln = $lines[$idx];
    $block .= $ln;
    my $open_count = ($ln =~ tr/(//);
    my $close_count = ($ln =~ tr/)//);
    if (!$started && $open_count > 0) {
      $started = 1;
      $depth = $open_count - $close_count;
    } elsif ($started) {
      $depth += $open_count - $close_count;
    }

    $end_idx = $idx;

    if ($started && $depth <= 0 && $idx > $start_idx) {
      last;
    }

    if (!$started && $idx - $start_idx >= 10) {
      last;
    }
  }

  return ($block, $end_idx);
}

sub _extract_label {
  my ($block) = @_;

  for my $pattern (
    qr/\b(?:label|title|tooltip)\s*:\s*'([^']+)'/s,
    qr/\b(?:label|title|tooltip)\s*:\s*"([^"]+)"/s,
    qr/\btitle\s*:\s*const\s+Text\s*\(\s*'([^']+)'/s,
    qr/\btitle\s*:\s*Text\s*\(\s*'([^']+)'/s,
    qr/\btitle\s*:\s*Text\s*\(\s*"([^"]+)"/s,
    qr/\bchild\s*:\s*const\s+Text\s*\(\s*'([^']+)'/s,
    qr/\bchild\s*:\s*Text\s*\(\s*'([^']+)'/s,
    qr/\bchild\s*:\s*Text\s*\(\s*"([^"]+)"/s,
    qr/_buildMenuBtn\s*\([^,]+,\s*'([^']+)'/s,
    qr/_buildSearchMenuMainAction\s*\(\s*label\s*:\s*'([^']+)'/s,
    qr/_buildSearchTopIconButton\s*\(\s*tooltip\s*:\s*'([^']+)'/s,
  ) {
    if ($block =~ $pattern) {
      my $value = _sanitize($1);
      next if $value =~ /\$\{/;
      return $value;
    }
  }

  for my $expr_pattern (
    qr/\b(?:label|title|tooltip)\s*:\s*([A-Za-z_][A-Za-z0-9_\.\(\)]*)\s*,/s,
    qr/\bchild\s*:\s*Text\s*\(\s*([A-Za-z_][A-Za-z0-9_\.\(\)]*)\s*[\),]/s,
    qr/\bchild\s*:\s*Text\s*\(\s*([^\n]+?)\s*(?:,|\))/s,
    qr/\btitle\s*:\s*Text\s*\(\s*([^\n]+?)\s*(?:,|\))/s,
  ) {
    if ($block =~ $expr_pattern) {
      my $expr = _sanitize($1);
      $expr =~ s/[\),\s]+$//;
      next if $expr eq '';
      return "expr:$expr";
    }
  }

  return '-';
}

sub _extract_trigger {
  my ($block, $widget_kind) = @_;

  for my $event (
    qw(onPressed onTap onLongPress onSelected onChanged onSubmitted))
  {
    if ($block =~ /\b$event\s*:\s*null\b/s) {
      return "$event=null";
    }
    if ($block =~ /\b$event\s*:\s*([A-Za-z_][A-Za-z0-9_\.]*)\b/s) {
      return "$event=$1";
    }
    if ($block =~ /\b$event\s*:\s*\([^)]*\)\s*=>/s) {
      return "$event=closure=>";
    }
    if ($block =~ /\b$event\s*:\s*\([^)]*\)\s*async\s*\{/s) {
      return "$event=closure_async";
    }
    if ($block =~ /\b$event\s*:\s*\([^)]*\)\s*\{/s) {
      return "$event=closure";
    }
    if ($block =~ /\b$event\s*:\s*\{/s) {
      return "$event=closure";
    }
    if ($block =~ /\b$event\s*:\s*([^\n,]+)/s) {
      my $handler = _sanitize($1);
      $handler =~ s/[\),\s]+$//;
      return "$event=$handler";
    }
  }

  return 'builder:helper' if $widget_kind eq 'ReaderLegacyMenuActions';
  return '-';
}

sub _build_snippet {
  my ($line) = @_;
  my $snippet = $line;
  $snippet =~ s/\s+/ /g;
  $snippet =~ s/^\s+|\s+$//g;
  return _sanitize($snippet);
}

sub _extract_module {
  my ($file) = @_;
  return 'app' if $file eq 'lib/main.dart';
  if ($file =~ m{^lib/features/([^/]+)/}) {
    return $1;
  }
  return 'other';
}

sub _extract_page {
  my ($file) = @_;
  my $page = $file;
  $page =~ s{^lib/}{};
  $page =~ s{\.dart$}{};
  return $page;
}

sub _sanitize {
  my ($text) = @_;
  $text //= '';
  $text =~ s/\r?\n/ /g;
  $text =~ s/\t/ /g;
  $text =~ s/\s+/ /g;
  $text =~ s/^\s+|\s+$//g;
  $text =~ s/\|/\\|/g;
  return $text;
}
