#!/usr/bin/perl -w

use strict;

use Getopt::Std;
use File::Which;
use HTML::Template;

use CVS::Metrics;

my %opts;
getopts('d:f:ht:vH', \%opts);

if ($opts{h}) {
	print "Usage: $0 [-h] [-f file.log] [-t title] [-H] [-d \"dirs ...\"]\n";
	print "\t-h : help\n";
	print "\t-d \"dirs ...\" : list of directories\n";
	print "\t-f file.log : off-line mode\n";
	print "\t-t title\n";
	print "\t-v : version\n";
	print "\t-H : append HEAD as a tag\n";
	exit(0);
}

if ($opts{v}) {
	print "$0\n";
	print "CVS::Metrics Version $CVS::Metrics::VERSION\n";
	exit(0);
}

my $cfg = ".cvs_metrics";
our ($title, @dirs, $regex_tag, $flg_head);
if ( -r $cfg) {
	print "reading $cfg\n";
	require $cfg;
}

my $cvs_logfile;
if ($opts{f}) {
	$cvs_logfile = $opts{f};
} else {
	my $cvs = FindCvs();
	$cvs_logfile = $cvs . " log |";
}

if ($opts{d}) {
	my $dirs = $opts{d};
	@dirs = split / /, $dirs;
}

if ($opts{t}) {
	$title = $opts{t};
} else {
	$title = "total" unless (defined $title);
}

if ($opts{H}) {
	$flg_head = 1;
}

unless (defined $regex_tag) {
	$regex_tag = '\d+';
}

=head1 NAME

cvs_energy - Extract metrics from cvs log

=head1 SYNOPSYS

cvs_energy [B<-h>] [B<-f> I<file.log>] [B<-t> I<title>] [B<-H>] [B<-d> "I<dirs> ..."]

=head1 OPTIONS

=over 8

=item -h

Display Usage.

=item -d

List of directories.

=item -f

Mode off-line.

=item -t

Specify the main title.

=item -H

append HEAD as a tag.

=back

=head1 DESCRIPTION

B<cvs_activity> parses B<cvs log> and produces an HTML report.

This report is composed of a list of plot charts, each chart represents the
energy in a directory between each tags.

This tool needs File::Which, GD, Chart::Plot::Canvas, HTML::Template and Parse::RecDescent modules.

=head2 Configuration file (.cvs_metrics)

If present, B<cvs_energy> reads the configuration file F<.cvs_metrics>
in the current directory. The file could contains the following variables :

 $title = "main";

 $regex_tag = '^V\d+';

 @dirs = ( "abc", "def" , "def/hij" );

 $flg_head = 1;		# or 0

=head1 SEE ALSO

cvs_tklog, cvs_activity

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

my $parser = new CVS::Metrics::Parser();
if ($parser) {
	my $cvs_log = $parser->parse($cvs_logfile);

	my @tags;
	my $timed = $cvs_log->getTimedTag();
	my %matched;
	while (my ($tag, $date) = each %{$timed}) {
		print "Tag: ", $tag;
		if ($tag =~ /$regex_tag/) {
			$matched{$date} = $tag;
			print " ... matched";
		}
		print "\n";
	}
	foreach (sort keys %matched) {
		push @tags, $matched{$_};
	}

	if ($flg_head) {
		push @tags, "HEAD";
		$cvs_log->insertHead();
	}

	GeneratePNG($cvs_log, \@tags, $title, @dirs);
	GenerateHTML($title, @dirs);
	print "Starting browser...";
	exec "e_${title}.html";
}

#######################################################################

sub FindCvs {
	my $cvs = which('cvs');

	if ( !defined $cvs and $^O eq 'MSWin32' ) {
		use Win32::TieRegistry(Delimiter => "/");

		my $cvs_setting = $Registry->{"HKEY_CURRENT_USER/Software/WinCvs/wincvs/CVS settings"};
		$cvs = $cvs_setting->{'/P_WhichCvs'};
		if (defined $cvs) {
			$cvs =~ s/[\000\001]//g;
			$cvs =~ s/wincvs\.exe\@$//;
			if ( -e "${cvs}CVSNT\\\\cvs.exe") {
				$cvs .= "CVSNT\\\\cvs.exe";
			} else {
				$cvs .= "cvs.exe";
			}
		}
	}

	die "$cvs not found !\n" unless (defined $cvs);

	warn "Using CVS : $cvs\n";
	return '"' . $cvs . '"';
}

#######################################################################

sub GeneratePNG {
	my ($cvs_log, $tags, $title, @dirs) = @_;

	my $img = $cvs_log->EnergyGD($tags, ".", $title, 600, 400);

	my $outfile = "e_${title}.png";
	$outfile =~ s/\//_/g;
	open OUT, "> $outfile"
			or die "can't open $outfile ($!).\n";
	binmode OUT, ":raw";
	print OUT $img->png();
	close OUT;

	for my $dir (@dirs) {
		$img = $cvs_log->EnergyGD($tags, $dir, $dir, 600, 400);

		$outfile = "e_${title}_${dir}.png";
		$outfile =~ s/\//_/g;
		open OUT, "> $outfile"
				or die "can't open $outfile ($!).\n";
		binmode OUT, ":raw";
		print OUT $img->png();
		close OUT;
	}
}

#######################################################################

sub GenerateHTML {
	my ($title, @dirs) = @_;

my $html = q{
<?xml version='1.0' encoding='ISO-8859-1'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml'>
  <head>
    <meta http-equiv='Content-Type' content='text/html; charset=ISO-8859-1' />
    <meta name='generator' content='<TMPL_VAR NAME=generator>' />
    <meta name='date' content='<TMPL_VAR NAME=date>' />
    <title>cvs_energy <!-- TMPL_VAR NAME=title --></title>
    <style type='text/css'>
      h1 {text-align: center}
    </style>
  </head>
  <body>
  <h1><!-- TMPL_VAR NAME=title --></h1>
  <hr />
  <!-- TMPL_LOOP NAME=loop -->
    <h2><!-- TMPL_VAR NAME=header --></h2>
    <img src='<TMPL_VAR NAME=img>' />
    <hr />
  <!-- /TMPL_LOOP -->
  <cite>Generated by cvs_energy (<!-- TMPL_VAR NAME=date -->)</cite>
  </body>
</html>
};

	my $template = new HTML::Template(
			scalarref	=> \$html
	);
	die "can't create template ($!).\n"
			unless (defined $template);

	my $now = localtime();
	my $generator = "cvs_energy " . $CVS::Metrics::VERSION . " (Perl " . $] . ")";
	my $path = "e_${title}.png";
	$path =~ s/\//_/g;
	my @loop = ( {
			header		=> $title,
			img			=> $path
	} );
	for my $dir (@dirs) {
		$path = "e_${title}_${dir}.png";
		$path =~ s/\//_/g;
		push @loop, {
				header		=> $dir,
				img			=> $path
		};
	}
	$template->param(
			generator	=> $generator,
			date		=> $now,
			title		=> $title,
			loop		=> \@loop,
	);

	my $filename = "e_${title}.html";
	open OUT, "> $filename"
			or die "can't open $filename ($!)\n";
	print OUT $template->output();
	close OUT;
}

