package Guiguts::HelpMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&about_pop_up )
}

sub about_pop_up {
	my $top = shift;
	my $about_text = <<EOM;
Guiguts.pl post processing toolkit/interface to gutcheck.

Provides easy to use interface to gutcheck and an array of
other useful postprocessing functions.

This version produced by a number of volunteers.
See the Thanks.txt file for details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Guiguts 1.0 prepared by Hunter Monroe and many others.
Original guiguts written by Stephen Schulze.
Partially based on the Gedi editor - Gregs editor.
Redistributable on the same terms as Perl.
EOM

	if ( defined( $::lglobal{aboutpop} ) ) {
		$::lglobal{aboutpop}->deiconify;
		$::lglobal{aboutpop}->raise;
		$::lglobal{aboutpop}->focus;
	} else {
		$::lglobal{aboutpop} = $top->Toplevel;
		&::initialize_popup_with_deletebinding('aboutpop');
		$::lglobal{aboutpop}->title('About');
		$::lglobal{aboutpop}->Label(
								   -justify => "left",
								   -text    => $about_text
		)->pack;
		my $button_ok = $::lglobal{aboutpop}->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$::lglobal{aboutpop}->destroy;
				undef $::lglobal{aboutpop};
			}
		)->pack( -pady => 6 );
		$::lglobal{aboutpop}->resizable( 'no', 'no' );
		$::lglobal{aboutpop}->raise;
		$::lglobal{aboutpop}->focus;
	}
}

1;


