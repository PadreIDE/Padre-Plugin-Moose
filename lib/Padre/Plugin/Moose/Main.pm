package Padre::Plugin::Moose::Main;

use 5.008;
use Moose;

use Padre::Plugin::Moose::FBP::Main ();
use Padre::Wx::Role::Dialog         ();

our $VERSION = '0.10';

our @ISA = qw{
	Padre::Plugin::Moose::FBP::Main
	Padre::Wx::Role::Dialog
};

sub new {
	my $class = shift;
	my $main  = shift;

	my $self = $class->SUPER::new($main);
	$self->CenterOnParent;
	$self->SetTitle(sprintf(
		Wx::gettext('Padre::Plugin::Moose %s - Written for fun by Ahmad M. Zawawi (azawawi)'), $VERSION)
	);

	$self->restore_defaults;

	# TODO Bug Alias to fix the wxFormBuilder bug regarding this one
	my $inspector = $self->{inspector};
	$inspector->SetRowLabelSize(0);

	for my $row ( 0 .. $inspector->GetNumberRows - 1 ) {
		$inspector->SetReadOnly( $row, 0 );
	}

	# Hide the inspector as needed
	$self->show_inspector(undef);

	# Setup preview editor
	my $preview = $self->{preview};
	require Padre::Document;
	$preview->{Document} = Padre::Document->new( mimetype => 'application/x-perl', );
	$preview->{Document}->set_editor($preview);
	$preview->SetLexer('application/x-perl');
	$preview->Show(1);

	$self->show_code_in_preview(1);

	return $self;
}

# This is called before the dialog is shown
sub run {
	my $self = shift;

	# Apply the current theme to the preview editor
	my $style = $self->main->config->editor_style;
	my $theme = Padre::Wx::Theme->find($style)->clone;
	$theme->apply( $self->{preview} );
}

# Set up the events
sub on_grid_cell_change {
	my $self = shift;

	my $element = $self->{current_element} or return;

	$element->read_from_inspector( $self->{inspector} )
		if $element->does('Padre::Plugin::Moose::Role::CanHandleInspector');

	$self->show_code_in_preview(0);
}

sub on_tree_selection_change {
	my $self  = shift;
	my $event = shift;

	my $tree    = $self->{tree};
	my $item    = $event->GetItem or return;
	my $element = $tree->GetPlData($item) or return;

	my $is_parent  = $element->does('Padre::Plugin::Moose::Role::HasClassMembers');
	my $is_program = $element->isa('Padre::Plugin::Moose::Program');

	# Show/Hide the inspector as needed
	$self->show_inspector( $is_program ? undef : $element );

	# Display help about the current element
	$self->{help}->SetValue( $element->provide_help );

	$self->{current_element} = $element;

	# Find parent element
	if ( $element->does('Padre::Plugin::Moose::Role::ClassMember') ) {
		$self->{current_parent} = $tree->GetPlData( $tree->GetItemParent($item) );
	} else {
		$self->{current_parent} = $element if $is_parent;
	}

	$self->Layout;

	# TODO improve the crude workaround to positioning
	unless ($is_program) {
		my $preview  = $self->{preview};
		my $line_num = 0;
		for my $line ( split /\n/, $preview->GetText ) {
			my $name = quotemeta $element->name;
			if ( $line =~ /$name/ ) {
				my $position = $preview->PositionFromLine($line_num);
				$preview->SetCurrentPos($position);
				$preview->SetAnchor($position);
				$preview->ScrollToLine($line_num);
				last;
			}
			$line_num++;
		}
	}
}

sub show_code_in_preview {
	my $self               = shift;
	my $should_select_item = shift;

	eval {

		# Generate code
		my $code = $self->{program}->generate_code(
			$self->{comments_checkbox}->IsChecked,
			$self->{sample_code_checkbox}->IsChecked
		);

		# And show it in preview editor
		my $preview = $self->{preview};
		$preview->SetReadOnly(0);
		$preview->SetText($code);
		$preview->SetReadOnly(1);

		# Update tree
		$self->update_tree($should_select_item);
	};
	if ($@) {
		$self->error( Wx::gettext( "Error: " . $@ ) );
	}
}

sub update_tree {
	my $self               = shift;
	my $should_select_item = shift;

	my $tree = $self->{tree};
	$tree->DeleteAllItems;

	my $selected_item;

	my $program      = $self->{program};
	my $program_node = $tree->AddRoot(
		Wx::gettext('Program'),
		-1,
		-1,
		Wx::TreeItemData->new($program)
	);

	if ( $program eq $self->{current_element} ) {
		$selected_item = $program_node;
	}

	for my $class ( @{ $program->roles }, @{ $program->classes } ) {
		my $class_node = $tree->AppendItem(
			$program_node,
			$class->name,
			-1, -1,
			Wx::TreeItemData->new($class)
		);
		for my $class_item ( @{ $class->attributes }, @{ $class->subtypes }, @{ $class->methods } ) {
			my $class_item_node = $tree->AppendItem(
				$class_node,
				$class_item->name,
				-1, -1,
				Wx::TreeItemData->new($class_item)
			);
			if ( $class_item == $self->{current_element} ) {
				$selected_item = $class_item_node;
			}
		}

		if ( $class == $self->{current_element} ) {
			$selected_item = $class_node;
		}

		$tree->Expand($class_node);
	}

	$tree->ExpandAll;

	# Select the tree node outside this event to
	# prevent deep recurision
	Wx::Event::EVT_IDLE(
		$self,
		sub {
			$tree->SelectItem($selected_item);
			Wx::Event::EVT_IDLE( $self, undef );
		}
		)
		if $should_select_item
			&& defined $selected_item;
}

sub show_inspector {
	my $self    = shift;
	my $element = shift;

	unless ( defined $element ) {
		$self->{inspector}->Show(0);
		return;
	}

	my $type = blessed($element);
	if ( ( not defined $type ) or ( $type !~ /(Class|Role|Attribute|Subtype|Method)$/ ) ) {
		$self->error("type: $element is not Class, Role, Attribute, Subtype or Method\n");
		return;
	}

	my $inspector_data = $element->get_grid_data;
	my $inspector      = $self->{inspector};
	$inspector->DeleteRows( 0, $inspector->GetNumberRows );
	$inspector->InsertRows( 0, scalar @$inspector_data );
	my $row_index = 0;
	for my $row (@$inspector_data) {
		$inspector->SetCellValue( $row_index, 0, $row->{name} );
		if ( defined $row->{is_bool} ) {
			$inspector->SetCellEditor( $row_index, 1, Wx::GridCellBoolEditor->new );
			$inspector->SetCellValue( $row_index, 1, 1 );
		} elsif ( defined $row->{choices} ) {
			$inspector->SetCellEditor( $row_index, 1, Wx::GridCellBoolEditor->new( $row->{choices} ) );
		}
		$row_index++;
	}

	$inspector->Show(1);
	$self->Layout;
	$inspector->SetGridCursor( 0, 1 );

	$element->write_to_inspector($inspector)
		if $element->does('Padre::Plugin::Moose::Role::CanHandleInspector');
}

sub on_add_class_button {
	my $self = shift;

	# Add a new class object to program
	require Padre::Plugin::Moose::Class;
	my $class = Padre::Plugin::Moose::Class->new;
	$class->name( "Class" . $self->{class_count}++ );
	$class->immutable(1);
	$class->namespace_autoclean(1);
	push @{ $self->{program}->classes }, $class;

	$self->{current_element} = $class;
	$self->show_inspector($class);
	$self->show_code_in_preview(1);
}

sub on_add_role_button {
	my $self = shift;

	# Add a new role object to program
	require Padre::Plugin::Moose::Role;
	my $role = Padre::Plugin::Moose::Role->new;
	$role->name( "Role" . $self->{role_count}++ );
	push @{ $self->{program}->roles }, $role;

	$self->{current_element} = $role;
	$self->show_inspector($role);
	$self->show_code_in_preview(1);
}

sub on_add_attribute_button {
	my $self = shift;

	# Only allowed within a class/role element
	unless ( defined $self->{current_element}
		&& defined $self->{current_parent}
		&& $self->{current_parent}->does('Padre::Plugin::Moose::Role::HasClassMembers') )
	{
		$self->error( Wx::gettext('You can only add an attribute to a class or role') );
		return;
	}

	# Add a new attribute object to class
	require Padre::Plugin::Moose::Attribute;
	my $attribute = Padre::Plugin::Moose::Attribute->new;
	$attribute->name( 'attribute' . $self->{attribute_count}++ );
	push @{ $self->{current_parent}->attributes }, $attribute;

	$self->{current_element} = $attribute;
	$self->show_inspector($attribute);
	$self->show_code_in_preview(1);
}

sub on_add_subtype_button {
	my $self = shift;

	# Only allowed within a class/role element
	unless ( defined $self->{current_element}
		&& defined $self->{current_parent}
		&& $self->{current_parent}->does('Padre::Plugin::Moose::Role::HasClassMembers') )
	{
		$self->error( Wx::gettext('You can only add a subtype to a class or role') );
		return;
	}

	# Add a new subtype object to class
	require Padre::Plugin::Moose::Subtype;
	my $subtype = Padre::Plugin::Moose::Subtype->new;
	$subtype->name( 'Subtype' . $self->{subtype_count}++ );
	push @{ $self->{current_parent}->subtypes }, $subtype;

	$self->{current_element} = $subtype;
	$self->show_inspector($subtype);
	$self->show_code_in_preview(1);
}

sub on_add_method_button {
	my $self = shift;

	# Only allowed within a class/role element
	unless ( defined $self->{current_element}
		&& defined $self->{current_parent}
		&& $self->{current_parent}->does('Padre::Plugin::Moose::Role::HasClassMembers') )
	{
		$self->error( Wx::gettext('You can only add a method to a class or role') );
		return;
	}

	# Add a new method object to class
	require Padre::Plugin::Moose::Method;
	my $method = Padre::Plugin::Moose::Method->new;
	$method->name( 'method_' . $self->{method_count}++ );
	push @{ $self->{current_parent}->methods }, $method;

	$self->{current_element} = $method;
	$self->show_inspector($method);
	$self->show_code_in_preview(1);
}

sub on_sample_code_checkbox {
	$_[0]->show_code_in_preview(1);
}

sub on_comments_checkbox {
	$_[0]->show_code_in_preview(1);
}

sub on_reset_button_clicked {
	my $self = shift;

	if ( $self->yes_no( Wx::gettext('Do you really want to reset?') ) ) {
		$self->restore_defaults;
		$self->show_code_in_preview(1);
	}
}

sub on_generate_code_button_clicked {
	my $self = shift;

	Wx::Event::EVT_IDLE(
		$self,
		sub {
			$self->main->new_document_from_string(
				$self->{preview}->GetText => 'application/x-perl',
			);
			Wx::Event::EVT_IDLE( $self, undef );
		}
	);

	$self->EndModal(Wx::ID_OK);
}

sub restore_defaults {
	my $self = shift;

	$self->{class_count}     = 1;
	$self->{role_count}      = 1;
	$self->{attribute_count} = 1;
	$self->{subtype_count}   = 1;
	$self->{method_count}    = 1;

	require Padre::Plugin::Moose::Program;
	$self->{program}         = Padre::Plugin::Moose::Program->new;
	$self->{current_element} = $self->{program};
	$self->{current_parent}  = $self->{program};

	# Defaults
	$self->{comments_checkbox}->SetValue(1);
	$self->{sample_code_checkbox}->SetValue(1);
}

1;

# Copyright 2008-2012 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
