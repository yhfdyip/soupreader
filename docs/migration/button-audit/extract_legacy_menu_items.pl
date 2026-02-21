#!/usr/bin/env perl
use strict;
use warnings;

my $menu_glob = '../legado/app/src/main/res/menu/*.xml';
my @files = sort glob($menu_glob);
my $idx = 0;

print join("\t", qw(index menu_file group_path item_id title_ref icon_ref show_as_action visible enabled checkable checked order_in_category)), "\n";

for my $file (@files) {
    open my $fh, '<', $file or die "open $file: $!";
    local $/;
    my $xml = <$fh>;
    close $fh;

    my @group_stack;

    while ($xml =~ /(<!--.*?-->|<[^>]+>)/sg) {
        my $tag = $1;

        next if $tag =~ /^<!--/s;
        next if $tag =~ /^<\?/;
        next if $tag =~ /^<!/;

        if ($tag =~ /^<group\b/s) {
            my $self_close = ($tag =~ /\/\s*>\s*$/s) ? 1 : 0;
            my $gid = '-';
            if ($tag =~ /android:id\s*=\s*"([^"]*)"/) {
                $gid = $1;
            }
            push @group_stack, $gid unless $self_close;
            next;
        }

        if ($tag =~ /^<\/group\b/s) {
            pop @group_stack if @group_stack;
            next;
        }

        if ($tag =~ /^<item\b/s) {
            $idx++;
            my %a = (
                'android:id' => '-',
                'android:title' => '-',
                'android:icon' => '-',
                'app:showAsAction' => '-',
                'android:visible' => '-',
                'android:enabled' => '-',
                'android:checkable' => '-',
                'android:checked' => '-',
                'android:orderInCategory' => '-',
            );

            while ($tag =~ /(android:[\w.:-]+|app:[\w.:-]+)\s*=\s*"([^"]*)"/g) {
                $a{$1} = $2;
            }

            my $menu = $file;
            $menu =~ s{^.*/}{};
            my $group_path = @group_stack ? join(' > ', @group_stack) : '-';

            my @row = (
                $idx,
                $menu,
                $group_path,
                $a{'android:id'},
                $a{'android:title'},
                $a{'android:icon'},
                $a{'app:showAsAction'},
                $a{'android:visible'},
                $a{'android:enabled'},
                $a{'android:checkable'},
                $a{'android:checked'},
                $a{'android:orderInCategory'},
            );

            for (@row) {
                s/\t/ /g;
                s/\n/ /g;
                s/\s+/ /g;
                s/^\s+|\s+$//g;
                $_ = '-' if $_ eq '';
            }

            print join("\t", @row), "\n";
            next;
        }
    }
}
