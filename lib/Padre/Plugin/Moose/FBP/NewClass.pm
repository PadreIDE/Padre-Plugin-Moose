package Padre::Plugin::Moose::FBP::NewClass;

## no critic

# This module was generated by Padre::Plugin::FormBuilder::Perl.
# To change this module edit the original .fbp file and regenerate.
# DO NOT MODIFY THIS FILE BY HAND!

use 5.008005;
use utf8;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.02';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Panel
};

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::DefaultPosition,
		[ 500, 300 ],
		Wx::TAB_TRAVERSAL,
	);

	my $class_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Class:"),
	);

	$self->{class_text} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	my $superclass_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Superclass:"),
	);

	$self->{superclass_text} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	my $roles_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Roles:"),
	);

	$self->{roles_list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
	);

	my $attributes_label = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Attributes:"),
	);

	$self->{attributes_list} = Wx::ListBox->new(
		$self,
		-1,
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[],
	);

	$self->{namespace_autoclean_label} = Wx::StaticText->new(
		$self,
		-1,
		Wx::gettext("Auto-clean namespace?"),
	);

	$self->{namespace_autoclean_checkbox} = Wx::CheckBox->new(
		$self,
		-1,
		'',
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	my $content_sizer = Wx::FlexGridSizer->new( 2, 2, 0, 0 );
	$content_sizer->SetFlexibleDirection(Wx::BOTH);
	$content_sizer->SetNonFlexibleGrowMode(Wx::FLEX_GROWMODE_SPECIFIED);
	$content_sizer->Add( $class_label, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );
	$content_sizer->Add( $self->{class_text}, 0, Wx::ALL, 5 );
	$content_sizer->Add( $superclass_label, 0, Wx::ALIGN_CENTER_VERTICAL | Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );
	$content_sizer->Add( $self->{superclass_text}, 0, Wx::ALL, 5 );
	$content_sizer->Add( $roles_label, 0, Wx::ALL, 5 );
	$content_sizer->Add( $self->{roles_list}, 0, Wx::ALL, 5 );
	$content_sizer->Add( $attributes_label, 0, Wx::ALL, 5 );
	$content_sizer->Add( $self->{attributes_list}, 0, Wx::ALL, 5 );
	$content_sizer->Add( $self->{namespace_autoclean_label}, 0, Wx::ALL, 5 );
	$content_sizer->Add( $self->{namespace_autoclean_checkbox}, 0, Wx::ALL, 5 );

	$self->SetSizer($content_sizer);
	$self->Layout;

	return $self;
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.

