package Padre::Plugin::Moose::Document;

use 5.008;
use strict;
use warnings;
use Padre::Document::Perl ();
use Padre::Logger;

our $VERSION = '0.18';

our @ISA = 'Padre::Document::Perl';

# Override SUPER::set_editor to hook up the key down and char events
sub set_editor {
	my $self   = shift;
	my $editor = shift;

	$self->SUPER::set_editor($editor);

	# TODO Padre should fire event_key_down instead of this hack :)
	# Register keyboard event handler for the current editor
	Wx::Event::EVT_KEY_DOWN( $editor, undef );
	Wx::Event::EVT_KEY_DOWN( $editor, sub { $self->on_key_down(@_); } );
	Wx::Event::EVT_CHAR( $editor, undef );
	Wx::Event::EVT_CHAR( $editor, sub { $self->on_char(@_); } );

	return;
}


# Override get_indentation_style to
sub get_indentation_style {
	my $self = shift;

	# Workaround to get moose plugin configuration... :)
	require Padre::Plugin::Moose;
	my $config = Padre::Plugin::Moose::_plugin_config();

	# Highlight Moose keywords after get_indentation_style is called :)
	$self->_highlight_moose_keywords( $config->{type} );

	# continue as normal
	return $self->SUPER::get_indentation_style;
}

# Called when the a key is pressed
sub on_key_down {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;

	# Workaround to get moose plugin configuration... :)
	require Padre::Plugin::Moose;
	my $config = Padre::Plugin::Moose::_plugin_config();

	# Shortcut if snippets feature is disabled
	unless ( $config->{snippets} ) {

		# Keep processing and exit
		$event->Skip(1);
		return;
	}

	# Load snippets everything since it be changed by the user at runtime
	$self->_load_snippets($config);

	# Highlight Moose keywords
	$self->_highlight_moose_keywords( $config->{type} );

	if ( $self->_can_end_snippet_mode($event) ) {
		$self->_end_snippet_mode($editor);
	} elsif ( defined $self->{_snippets} && $event->GetKeyCode == Wx::WXK_TAB ) {
		my $result =
			  $event->ShiftDown()
			? $self->_previous_variable($editor)
			: $self->_start_snippet_mode($editor);
		if ( defined $result ) {

			# Consume the <TAB>-triggerred snippet event
			return;
		}
	}

	# Keep processing events
	$event->Skip(1);

	return;
}

# Called when a printable character is typed
sub on_char {
	my $self   = shift;
	my $editor = shift;
	my $event  = shift;

	unless ( defined $self->{variables} ) {

		# Keep processing
		$event->Skip(1);
		return;
	}

	my $vars    = $self->{variables};
	my $old_pos = $editor->GetCurrentPos;
	my $new_pos = $old_pos;
	for my $var (@$vars) {
		if ( $self->{selected_index} == $var->{index} ) {
			if ( defined $self->{pristine} ) {
				$old_pos -= length $var->{value};
				$var->{value}     = chr( $event->GetKeyCode );
				$self->{pristine} = undef;
			} else {
				$var->{value} .= chr( $event->GetKeyCode );
			}
			$new_pos += length $var->{value};
			last;
		}
	}

	# Expand the snippet
	my ( $text, $cursor ) = $self->_expand_snippet( $self->{_snippet} );

	#my $pos = $self->{_pos};
	#my $len = length $self->{_trigger};
	#$editor->SetTargetStart( $pos - $len );
	#$editor->SetTargetEnd( $pos - $len + length $text );
	#	$editor->ReplaceTarget($text);
	#$editor->GotoPos($new_pos);

	# Keep processing
	$event->Skip(1);
	return;
}

# Called by the Padre editor when a mouse up event occurs
sub event_on_left_up {
	$_[0]->_end_snippet_mode( $_[1] );
}

sub _end_snippet_mode {
	my $self   = shift;
	my $editor = shift;

	if ( defined $self->{variables} ) {

		# Stop snippet mode
		$self->{variables} = undef;

		# Clear the selected text
		my $current_pos = $editor->GetCurrentPos;
		$editor->SetSelection( $current_pos, $current_pos );
	}
}

# Load snippets from file according to code generation type
sub _load_snippets {
	my $self   = shift;
	my $config = shift;

	eval {
		require YAML;
		require File::ShareDir;
		require File::Spec;

		# Determine the snippets filename
		my $file;
		my $type = $config->{type};
		if ( $type eq 'Mouse' ) {

			# Mouse snippets
			$file = 'mouse.yml';
		} elsif ( $type eq 'MooseX::Declare' ) {

			# MooseX::Declare snippets
			$file = 'moosex_declare.yml';
		} else {

			# Moose by default
			$file = 'moose.yml';
		}

		# Shortcut if that snippet type is already loaded in memory
		return
			if defined( $self->{_snippets_type} )
				and ( $type eq $self->{_snippets_type} );

		# Determine the full share/${snippets_filename}
		my $filename = File::ShareDir::dist_file(
			'Padre-Plugin-Moose',
			File::Spec->catfile( 'snippets', $file )
		);

		# Read it via standard YAML
		$self->{_snippets} = YAML::LoadFile($filename);

		# Record loaded snippet type
		$self->{_snippets_type} = $type;
	};

	# Report error to padre logger
	TRACE("Unable to load snippet. Reason: $@\n")
		if $@ && DEBUG;

	return;
}

# Returns whether the key can end snippet mode or not
sub _can_end_snippet_mode {
	my $self  = shift;
	my $event = shift;

	my $key = $event->GetKeyCode;
	return
		   $event->ControlDown && $key != Wx::WXK_TAB
		|| $event->AltDown
		|| ( $key == Wx::WXK_ESCAPE
		|| $key == Wx::WXK_UP
		|| $key == Wx::WXK_DOWN
		|| $key == Wx::WXK_RIGHT
		|| $key == Wx::WXK_LEFT
		|| $key == Wx::WXK_HOME
		|| $key == Wx::WXK_END
		|| $key == Wx::WXK_DELETE
		|| $key == Wx::WXK_PAGEUP
		|| $key == Wx::WXK_PAGEDOWN
		|| $key == Wx::WXK_NUMPAD_UP
		|| $key == Wx::WXK_NUMPAD_DOWN
		|| $key == Wx::WXK_NUMPAD_RIGHT
		|| $key == Wx::WXK_NUMPAD_LEFT
		|| $key == Wx::WXK_NUMPAD_HOME
		|| $key == Wx::WXK_NUMPAD_END
		|| $key == Wx::WXK_NUMPAD_DELETE
		|| $key == Wx::WXK_NUMPAD_PAGEUP
		|| $key == Wx::WXK_NUMPAD_PAGEDOWN );
}

# Adds Moose/Mouse/MooseX::Declare keywords highlighting
sub _highlight_moose_keywords {

	# TODO remove hack once Padre supports a better way
	require Padre::Plugin::Moose::Util;
	Padre::Plugin::Moose::Util::add_moose_keywords_highlighting( $_[0], $_[1] );
}

# Called when SHIFT-TAB is pressed
sub _previous_variable {
	my $self   = shift;
	my $editor = shift;

	# Only in snippet mode
	return unless defined $self->{variables};

	# Already in snippet mode
	$self->{selected_index}--;

	if ( $self->{selected_index} < 1 ) {

		# Shift-tabbing to traverse them in circular fashion
		$self->{selected_index} = $self->{last_index};
	}

	$self->{pristine} = 1;

	for my $var ( @{ $self->{variables} } ) {
		if ( $var->{index} == $self->{selected_index} ) {
			my $start = $self->{_pos} - length( $self->{_trigger} ) + $var->{start};
			$editor->GotoPos($start);
			$editor->SetSelection( $start, $start + length( $var->{value} ) );

			last;
		}
	}

	return 1;
}

# Starts snippet mode when TAB is pressed
sub _start_snippet_mode {
	my $self   = shift;
	my $editor = shift;

	my ( $pos, $snippet, $trigger ) = $self->_prepare_snippet_info($editor) or return;
	my ( $first_time, $last_time ) = $self->_build_variables_info($snippet);

	# Prepare to replace variables
	# Find the next cursor
	my ( $text, $cursor ) = $self->_expand_snippet($snippet);

	# We paste the snippet and position the cursor to
	$self->_insert_snippet( $editor, $cursor, $text, $first_time, $last_time );

	# Snippet inserted
	return 1;
}

sub _prepare_snippet_info {
	my $self   = shift;
	my $editor = shift;

	my ( $pos, $snippet, $trigger );
	if ( defined $self->{variables} ) {
		$pos     = $self->{_pos};
		$snippet = $self->{_snippet};
		$trigger = $self->{_trigger};
	} else {
		$pos = $editor->GetCurrentPos;
		my $line = $editor->GetTextRange(
			$editor->PositionFromLine( $editor->LineFromPosition($pos) ),
			$pos
		);

		my $snippet_obj = $self->_find_snippet($line);
		return unless defined $snippet_obj;

		$self->{_pos} = $pos;
		$snippet = $self->{_snippet} = $snippet_obj->{snippet};
		$trigger = $self->{_trigger} = $snippet_obj->{trigger};
	}

	return ( $pos, $snippet, $trigger );
}

# Collect and highlight all variables in the snippet
sub _build_variables_info {
	my $self    = shift;
	my $snippet = shift;
	my $vars;
	my $first_time;
	my $last_time;
	if ( defined $self->{variables} ) {

		# Already in snippet mode
		$vars = $self->{variables};
		$self->{selected_index}++;

		if ( $self->{selected_index} > $self->{last_index} ) {

			# exit snippet mode and position at end
			$self->{variables} = undef;
			$last_time = 1;
		}
		$self->{pristine} = 1;

	} else {

		# Not defined, create an empty one
		$vars = $self->{variables} = [];
		$self->{selected_index} = 1;
		$self->{pristine}       = 1;
		$first_time             = 1;

		# Build snippet variables array
		my $last_index = 0;
		while (
			$snippet =~ /
			(		# int is integer
			\${(\d+)(?: \:((?:[^\\]|\\.)*?))?}     # ${int:default value} or ${int}
			|  \$(\d+)              # $int
		)/gx
			)
		{
			my $index = defined $4 ? int($4) : int($2);
			if ( $last_index < $index ) {
				$last_index = $index;
			}
			my $value = $3;
			if ( defined $value ) {

				# expand escaped text
				$value =~ s/\\(.)/$1/g;
			}
			my $var = {
				index      => $index,
				text       => $1,
				value      => $value,
				orig_start => pos($snippet) - length($1),
				start      => pos($snippet) - length($1),
			};
			push @$vars, $var;
		}
		$self->{last_index} = $last_index;
	}

	return ( $first_time, $last_time );
}

# Returns the snippet template or undef
sub _find_snippet {
	my $self = shift;
	my $line = shift;

	my %snippets = %{ $self->{_snippets} };
	for my $trigger ( keys %snippets ) {
		if ( $line =~ /\b\Q$trigger\E$/ ) {
			return {
				trigger => $trigger,
				snippet => $snippets{$trigger},
			};
		}
	}

	return;
}

# Returns an expanded snippet with all the variables filled in
sub _expand_snippet {
	my $self = shift;
	my $text = shift;
	my $cursor;
	my $count = 0;
	my $vars  = $self->{variables};
	for my $var (@$vars) {
		unless ( defined $var->{value} ) {
			my $index = $var->{index};
			for my $v (@$vars) {
				my $value = $v->{value};
				if ( ( $v->{index} == $index ) && defined $value ) {
					my $before_length = length $text;
					$v->{start} = $v->{orig_start} + $count;
					substr( $text, $v->{start}, length $v->{text} ) = $value;
					$count += length($text) - $before_length;
					last;
				}
			}
		} else {
			my $before_length = length $text;
			$var->{start} = $var->{orig_start} + $count;
			substr( $text, $var->{start}, length $var->{text} ) = $var->{value};
			$count += length($text) - $before_length;

			if ( $var->{index} == $self->{selected_index} ) {
				$cursor = $var;
			}
		}

	}

	return ( $text, $cursor );
}

sub _insert_snippet {
	my $self       = shift;
	my $editor     = shift;
	my $cursor     = shift;
	my $text       = shift;
	my $first_time = shift;
	my $last_time  = shift;

	my $pos            = $self->{_pos};
	my $start_position = $pos - length( $self->{_trigger} );
	if ($first_time) {
		$editor->SetTargetStart($start_position);
		$editor->SetTargetEnd($pos);
		$editor->ReplaceTarget($text);

		my $start = $start_position + $cursor->{start};
		$editor->GotoPos($start);
		$editor->SetSelection( $start, $start + length $cursor->{value} );
	} else {
		if ($last_time) {
			$editor->GotoPos( $start_position + length $text );
		} else {
			$editor->SetTargetStart($start_position);
			$editor->SetTargetEnd( $start_position + length $text );
			$editor->ReplaceTarget($text);

			my $start = $start_position + $cursor->{start};
			$editor->GotoPos($start);
			$editor->SetSelection( $start, $start + length $cursor->{value} );
		}
	}
}


1;

__END__

=pod

=head1 NAME

Padre::Plugin::Moose::Document - A Perl document that understands Moose

=cut
