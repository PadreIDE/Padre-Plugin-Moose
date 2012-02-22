package Padre::Plugin::Moose::Method;

use namespace::clean;
use Moose;

our $VERSION = '0.06';

with 'Padre::Plugin::Moose::CodeGen';

has 'name' => ( is => 'rw', isa => 'Str' );

sub to_code {
	return "sub " . $_[0]->name . " { }\n";
}

sub help_string {
	require Wx;
	return Wx::gettext('A method is a subroutine within a class that defines behavior at runtime');
}

__PACKAGE__->meta->make_immutable;

1;
