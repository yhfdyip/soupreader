#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

my $legacy_script = 'docs/migration/button-audit/extract_legacy_menu_items.pl';
my $soup_script = 'docs/migration/button-audit/extract_soupreader_button_entries.pl';
my $zh_strings_path = '../legado/app/src/main/res/values-zh/strings.xml';

my %zh_strings = _load_zh_strings($zh_strings_path);
my @soup_entries = _load_tsv_from_script($soup_script);
my @legacy_entries = _load_tsv_from_script($legacy_script);

my %soup_by_norm;
my %soup_by_module;
my %first_soup_by_file;
my @fallback_entries;

for my $entry (@soup_entries) {
  my $label = $entry->{label} // '-';
  my $module = $entry->{module} // _derive_module_from_file($entry->{file} // '');
  $entry->{module} = $module;
  $entry->{seq} = int($entry->{seq} // 0);

  push @{ $soup_by_module{$module} }, $entry;

  if (!exists $first_soup_by_file{$entry->{file}}) {
    $first_soup_by_file{$entry->{file}} = $entry;
  }

  push @fallback_entries, $entry if $label ne '-';

  next if $label eq '-';
  my $norm = _normalize_label($label);
  next if $norm eq '';
  $entry->{norm_label} = $norm;
  push @{ $soup_by_norm{$norm} }, $entry;
}

print _csv_row(
  qw(
    legacy_index
    legacy_menu_file
    legacy_item_id
    legacy_title_ref
    legacy_title_zh
    soup_seq
    soup_file
    soup_label
    mapping_status
    candidate_count
    candidate_seqs
    notes
  )
);

my %selected_file_count_by_menu;

for my $legacy (@legacy_entries) {
  my $menu_file = $legacy->{menu_file} // '';
  my $context = _context_for_menu($menu_file);
  my $title_ref = $legacy->{title_ref} // '-';
  my $legacy_title_zh = _resolve_legacy_title($title_ref, \%zh_strings);
  my $legacy_norm = _normalize_label($legacy_title_zh);

  my @candidate_rows;
  my @candidate_entries;

  if ($legacy_norm ne '' && exists $soup_by_norm{$legacy_norm}) {
    for my $entry (@{ $soup_by_norm{$legacy_norm} }) {
      my $score = 1000 + _score_candidate(
        $legacy,
        $legacy_norm,
        $entry,
        $context,
        $selected_file_count_by_menu{$menu_file} // {},
      );
      push @candidate_rows, {
        entry => $entry,
        score => $score,
        origin => 'exact',
      };
    }
  } elsif ($legacy_norm ne '') {
    my @fuzzy = _find_fuzzy_candidates($legacy_norm, \@soup_entries);
    for my $item (@fuzzy) {
      my $entry = $item->{entry};
      my $score = ($item->{score} // 0) + _score_candidate(
        $legacy,
        $legacy_norm,
        $entry,
        $context,
        $selected_file_count_by_menu{$menu_file} // {},
      );
      push @candidate_rows, {
        entry => $entry,
        score => $score,
        origin => 'fuzzy',
        fuzzy_forward => $item->{forward} // 0,
        fuzzy_backward => $item->{backward} // 0,
        fuzzy_quality => $item->{quality} // 0,
      };
    }
  }

  @candidate_rows = sort {
       $b->{score} <=> $a->{score}
    || ($a->{entry}{seq} // 0) <=> ($b->{entry}{seq} // 0)
  } @candidate_rows;

  @candidate_entries = map { $_->{entry} } @candidate_rows;

  my $selected;
  my $mapping_status = '';
  my $notes = '';
  my $candidate_count = scalar(@candidate_entries);
  my $candidate_seqs = @candidate_entries
    ? join('|', map { $_->{seq} } @candidate_entries)
    : '';
  my $output_label = '';

  if (@candidate_rows && _should_accept_candidate($legacy_norm, $candidate_rows[0])) {
    $selected = $candidate_rows[0]{entry};
    $selected_file_count_by_menu{$menu_file}{ $selected->{file} }++;
    $output_label = $selected->{label} // '';

    if ($candidate_rows[0]{origin} eq 'exact' && @candidate_rows == 1) {
      $mapping_status = 'mapped_exact';
    } elsif ($candidate_rows[0]{origin} eq 'exact') {
      $mapping_status = 'mapped_exact_context';
      $notes = 'resolved_exact_by_menu_context';
    } else {
      $mapping_status = 'mapped_fuzzy_context';
      $notes = 'resolved_fuzzy_by_menu_context';
    }
  } else {
    $selected = _pick_placeholder_entry(
      $menu_file,
      $context,
      \%selected_file_count_by_menu,
      \%first_soup_by_file,
      \%soup_by_module,
      \@fallback_entries,
    );
    $selected_file_count_by_menu{$menu_file}{ $selected->{file} }++
      if defined $selected->{file} && $selected->{file} ne '';
    $mapping_status = 'mapped_placeholder';
    $output_label = "TODO:$legacy_title_zh";
    $notes = 'placeholder_by_menu_context:' . ($selected->{label} // '-');
    $candidate_seqs = $selected->{seq} // '';
  }

  print _csv_row(
    $legacy->{index} // '',
    $menu_file,
    $legacy->{item_id} // '',
    $title_ref,
    $legacy_title_zh,
    $selected ? ($selected->{seq} // '') : '',
    $selected ? ($selected->{file} // '') : '',
    $output_label,
    $mapping_status,
    $candidate_count,
    $candidate_seqs,
    $notes,
  );
}

sub _load_zh_strings {
  my ($path) = @_;
  my %strings;

  open my $fh, '<', $path or die "open $path failed: $!";
  binmode $fh, ':encoding(UTF-8)';
  local $/ = undef;
  my $xml = <$fh>;
  close $fh;

  while ($xml =~ /<string\s+name="([^"]+)"[^>]*>(.*?)<\/string>/sg) {
    my ($name, $value) = ($1, $2);
    $value =~ s/<!\[CDATA\[(.*?)\]\]>/$1/gs;
    $value = _decode_xml_entities($value);
    $value =~ s/\s+/ /g;
    $value =~ s/^\s+|\s+$//g;
    $strings{$name} = $value;
  }

  return %strings;
}

sub _load_tsv_from_script {
  my ($script) = @_;
  open my $fh, '-|', 'perl', $script
    or die "run perl $script failed: $!";
  binmode $fh, ':encoding(UTF-8)';

  my $header = <$fh>;
  die "empty output from $script" unless defined $header;
  chomp $header;
  my @columns = split /\t/, $header, -1;

  my @rows;
  while (my $line = <$fh>) {
    chomp $line;
    next if $line eq '';
    my @fields = split /\t/, $line, -1;
    my %row;
    for my $i (0 .. $#columns) {
      my $col = $columns[$i];
      my $val = defined $fields[$i] ? $fields[$i] : '';
      $row{$col} = $val;
    }
    push @rows, \%row;
  }
  close $fh;

  return @rows;
}

sub _resolve_legacy_title {
  my ($title_ref, $zh_ref) = @_;
  return '-' if !defined $title_ref || $title_ref eq '-' || $title_ref eq '';

  if ($title_ref =~ /^\@string\/(.+)$/) {
    my $name = $1;
    return exists $zh_ref->{$name} ? $zh_ref->{$name} : $title_ref;
  }

  if ($title_ref =~ /^\@android:string\/(.+)$/) {
    return $1;
  }

  return $title_ref;
}

sub _derive_module_from_file {
  my ($file) = @_;
  return 'app' if $file eq 'lib/main.dart';
  if ($file =~ m{^lib/features/([^/]+)/}) {
    return $1;
  }
  return 'other';
}

sub _context_for_menu {
  my ($menu_file) = @_;

  my @rules = (
    {
      pattern => qr/^(book_read|book_toc|book_manga|content_|font_select|theme_|speak_engine|txt_toc_rule|dict_rule|replace_|keyboard_assists_config|code_edit|dialog_text)/,
      modules => [qw(reader settings replace search)],
      files => [
        qr/simple_reader_view\.dart$/,
        qr/reading_preferences_view\.dart$/,
        qr/replace_rule_(?:list|edit)_view\.dart$/,
        qr/settings_view\.dart$/,
      ],
    },
    {
      pattern => qr/^(book_source|source_|import_source|rss_source|verification_code|web_view|source_sub_item|source_subscription|direct_link_upload_config|server_config|servers|file_chooser|file_long_click|qr_code_scan)/,
      modules => [qw(source rss discovery settings)],
      files => [
        qr/source_(?:list|edit|debug_legacy)_view\.dart$/,
        qr/rss_source_manage_view\.dart$/,
        qr/discovery_view\.dart$/,
      ],
    },
    {
      pattern => qr/^(rss_|main_rss)/,
      modules => [qw(rss source discovery bookshelf)],
      files => [
        qr/rss_.*\.dart$/,
        qr/source_.*\.dart$/,
        qr/discovery_view\.dart$/,
      ],
    },
    {
      pattern => qr/^(book_info|book_search|change_source|explore_item|main_explore|search_view|open_url_confirm|book_read_change_source|book_read_refresh|book_search_scope|change_source_item)/,
      modules => [qw(search discovery reader source)],
      files => [
        qr/search_(?:view|book_info_view)\.dart$/,
        qr/discovery_view\.dart$/,
        qr/simple_reader_view\.dart$/,
      ],
    },
    {
      pattern => qr/^(main_bookshelf|bookshelf_|book_cache|book_group_manage|bookmark|book_remote|import_book|app_log|crash_log|main_bnv|main_my|about|backup_restore|app_update)/,
      modules => [qw(bookshelf settings source rss)],
      files => [
        qr/bookshelf_view\.dart$/,
        qr/reading_history_view\.dart$/,
        qr/settings_.*\.dart$/,
      ],
    },
    {
      pattern => qr/^(group_manage|save|source_picker|content_search|book_info_edit|dict_rule_edit|txt_toc_rule_edit|replace_edit|import_replace)/,
      modules => [qw(settings source replace reader)],
      files => [
        qr/settings_view\.dart$/,
        qr/source_.*\.dart$/,
        qr/replace_rule_.*\.dart$/,
      ],
    },
  );

  for my $rule (@rules) {
    if ($menu_file =~ $rule->{pattern}) {
      return {
        modules => $rule->{modules},
        files => $rule->{files},
      };
    }
  }

  return {
    modules => [qw(settings source search)],
    files => [qr/settings_view\.dart$/, qr/source_list_view\.dart$/, qr/search_view\.dart$/],
  };
}

sub _score_candidate {
  my ($legacy, $legacy_norm, $entry, $context, $selected_file_count_ref) = @_;
  my $score = 0;

  my $module = $entry->{module} // '';
  for my $i (0 .. $#{ $context->{modules} }) {
    my $target = $context->{modules}[$i];
    next unless $module eq $target;
    $score += 140 - $i * 20;
  }

  my $file = $entry->{file} // '';
  for my $i (0 .. $#{ $context->{files} }) {
    my $regex = $context->{files}[$i];
    next unless $file =~ $regex;
    $score += 100 - $i * 15;
    last;
  }

  my $file_hits = $selected_file_count_ref->{$file} // 0;
  $score += $file_hits * 30 if $file_hits > 0;

  my $entry_norm = $entry->{norm_label} // _normalize_label($entry->{label} // '');
  if ($entry_norm ne '' && $legacy_norm ne '') {
    if ($entry_norm eq $legacy_norm) {
      $score += 80;
    } elsif (index($entry_norm, $legacy_norm) >= 0 || index($legacy_norm, $entry_norm) >= 0) {
      $score += 30;
    }

    my $common = _common_char_count($legacy_norm, $entry_norm);
    $score += $common * 5 if $common > 0;
  }

  my $item_id = $legacy->{item_id} // '';
  if ($item_id =~ /source/i && $module eq 'source') {
    $score += 25;
  }
  if ($item_id =~ /rss/i && $module eq 'rss') {
    $score += 25;
  }
  if ($item_id =~ /(read|toc|chapter)/i && $module eq 'reader') {
    $score += 25;
  }
  if ($item_id =~ /(search|book_info)/i && $module eq 'search') {
    $score += 20;
  }

  return $score;
}

sub _pick_placeholder_entry {
  my (
    $menu_file,
    $context,
    $selected_by_menu_ref,
    $first_soup_by_file_ref,
    $soup_by_module_ref,
    $fallback_entries_ref,
  ) = @_;

  my $menu_selected = $selected_by_menu_ref->{$menu_file} // {};

  for my $regex (@{ $context->{files} }) {
    for my $entry (@{$fallback_entries_ref}) {
      next unless ($entry->{file} // '') =~ $regex;
      return $entry;
    }
  }

  for my $module (@{ $context->{modules} }) {
    next unless exists $soup_by_module_ref->{$module};
    for my $entry (@{ $soup_by_module_ref->{$module} }) {
      next if ($entry->{label} // '-') eq '-';
      return $entry;
    }
  }

  my @by_freq = sort {
       ($menu_selected->{$b} // 0) <=> ($menu_selected->{$a} // 0)
    || $a cmp $b
  } keys %{$menu_selected};

  for my $file (@by_freq) {
    next unless exists $first_soup_by_file_ref->{$file};
    return $first_soup_by_file_ref->{$file};
  }

  return $fallback_entries_ref->[0] if @{$fallback_entries_ref};
  return {
    seq => '',
    file => '',
    label => '-',
    module => 'other',
  };
}

sub _should_accept_candidate {
  my ($legacy_norm, $top_row) = @_;
  return 0 if !defined $top_row;

  my $origin = $top_row->{origin} // '';
  return 1 if $origin eq 'exact';

  my $forward = $top_row->{fuzzy_forward} // 0;
  my $backward = $top_row->{fuzzy_backward} // 0;
  return 1 if $forward || $backward;

  my $quality = $top_row->{fuzzy_quality} // 0;
  my $legacy_len = length($legacy_norm // '');
  return 0 if $legacy_len >= 4 && $quality < 0.40;
  return 0 if $legacy_len < 4 && $quality < 0.55;
  return 1;
}

sub _find_fuzzy_candidates {
  my ($legacy_norm, $soup_entries_ref) = @_;
  my @scored;
  my $legacy_has_han = ($legacy_norm =~ /\p{Han}/) ? 1 : 0;
  my $legacy_han_len = _han_length($legacy_norm);

  for my $entry (@{$soup_entries_ref}) {
    my $label = $entry->{label} // '-';
    next if $label eq '-';
    my $soup_norm = _normalize_label($label);
    next if $soup_norm eq '';

    my $forward = index($soup_norm, $legacy_norm) >= 0;
    my $backward = index($legacy_norm, $soup_norm) >= 0;
    my $common = _common_char_count($legacy_norm, $soup_norm);
    my $common_han = _common_han_char_count($legacy_norm, $soup_norm);
    my $soup_has_han = ($soup_norm =~ /\p{Han}/) ? 1 : 0;
    my $soup_han_len = _han_length($soup_norm);
    my $quality = 0;

    if ($forward || $backward) {
      $quality = 1;
    } elsif ($legacy_has_han || $soup_has_han) {
      next if $common_han < 2;
      my $han_base = $legacy_han_len > $soup_han_len ? $legacy_han_len : $soup_han_len;
      $han_base = 1 if $han_base < 1;
      $quality = $common_han / $han_base;
    } else {
      next if $common < 3;
      my $base = length($legacy_norm) > length($soup_norm)
        ? length($legacy_norm)
        : length($soup_norm);
      $base = 1 if $base < 1;
      $quality = $common / $base;
    }

    my $len_gap = abs(length($soup_norm) - length($legacy_norm));
    my $score = 240 - ($len_gap * 2);
    $score += 80 if $forward;
    $score += 20 if $backward;
    $score += $common_han * 12;
    $score += $common * 2;
    $score += int($quality * 120);

    push @scored, {
      score => $score,
      entry => $entry,
      forward => $forward ? 1 : 0,
      backward => $backward ? 1 : 0,
      quality => $quality,
    };
  }

  @scored = sort {
       $b->{score} <=> $a->{score}
    || ($a->{entry}{seq} // 0) <=> ($b->{entry}{seq} // 0)
  } @scored;

  my $limit = $#scored < 6 ? $#scored : 6;
  return () if $limit < 0;
  return @scored[0 .. $limit];
}

sub _common_char_count {
  my ($a, $b) = @_;
  return 0 if !defined $a || !defined $b || $a eq '' || $b eq '';

  my %seen;
  $seen{$_}++ for split //, $a;
  my $count = 0;
  for my $ch (split //, $b) {
    next if !$seen{$ch};
    $count++;
    $seen{$ch} = 0;
  }

  return $count;
}

sub _common_han_char_count {
  my ($a, $b) = @_;
  my $ha = join('', $a =~ /(\p{Han})/g);
  my $hb = join('', $b =~ /(\p{Han})/g);
  return _common_char_count($ha, $hb);
}

sub _han_length {
  my ($text) = @_;
  my @han = ($text =~ /(\p{Han})/g);
  return scalar(@han);
}

sub _normalize_label {
  my ($text) = @_;
  $text //= '';
  $text =~ s/^expr://;
  $text =~ s/\$\{[^\}]*\}//g;
  $text =~ s/["'`]+//g;
  $text =~ s/[：:]/ /g;
  $text =~ s/\s+/ /g;
  $text =~ s/^\s+|\s+$//g;
  $text = lc($text);

  my %synonym = (
    '离线缓存' => '下载',
    '缓存导出' => '导出',
    '设置编码' => '编码',
    '换源' => '换源',
    '登录' => '登录',
  );

  for my $from (keys %synonym) {
    my $to = $synonym{$from};
    $text =~ s/$from/$to/g;
  }

  $text =~ s/%s//g;
  $text =~ s/\d+//g;
  $text =~ s/[^\p{Han}a-z0-9]+//g;
  return $text;
}

sub _decode_xml_entities {
  my ($value) = @_;
  $value =~ s/&quot;/"/g;
  $value =~ s/&apos;/'/g;
  $value =~ s/&lt;/</g;
  $value =~ s/&gt;/>/g;
  $value =~ s/&amp;/&/g;
  return $value;
}

sub _csv_row {
  my @values = @_;
  my @escaped = map {
    my $v = defined $_ ? $_ : '';
    $v =~ s/"/""/g;
    '"' . $v . '"';
  } @values;
  return join(',', @escaped) . "\n";
}
