package Padre::Plugin::Moose::Program;

use Moose;
use namespace::clean;

our $VERSION = '0.13';

with 'Padre::Plugin::Moose::Role::CanGenerateCode';
with 'Padre::Plugin::Moose::Role::CanProvideHelp';

has 'roles'   => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'classes' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );

sub generate_moose_code {
	my $self        = shift;
	my $code_gen_options    = shift;

	my $code = '';

	# Generate roles
	for my $role ( @{ $self->roles } ) {
		$code .= $role->generate_moose_code( $code_gen_options );
	}

	# Generate classes
	for my $class ( @{ $self->classes } ) {
		$code .= $class->generate_moose_code( $code_gen_options );
	}

	# Generate sample usage code
	if ($code_gen_options->{sample_code}) {
		$code .= "\npackage main;\n";
		my $count = 1;
		for my $class ( @{ $self->classes } ) {
			if ( $class->singleton ) {
				$code .= "my \$o$count = " . $class->name . "->instance;\n";
			} else {
				$code .= "my \$o$count = " . $class->name . "->new;\n";
			}
			$count++;
		}
	}

	return $code;
}

# Generate Mouse code!
sub generate_mouse_code {
	my $self        = shift;
	my $code_gen_options    = shift;

	my $code = '';

	# Generate roles
	for my $role ( @{ $self->roles } ) {
		$code .= $role->generate_mouse_code( $code_gen_options );
	}

	# Generate classes
	for my $class ( @{ $self->classes } ) {
		$code .= $class->generate_mouse_code( $code_gen_options );
	}

	# Generate sample usage code
	if ($code_gen_options->{sample_code}) {
		$code .= "\npackage main;\n";
		my $count = 1;
		for my $class ( @{ $self->classes } ) {
			$code .= "my \$o$count = " . $class->name . "->new;\n";
			$count++;
		}
	}

	return $code;
};

sub generate_moosex_declare_code {
	my $self        = shift;
	my $code_gen_options    = shift;

	my $code = '';

	# Generate roles
	for my $role ( @{ $self->roles } ) {
		$code .= $role->generate_moosex_declare_code( $code_gen_options );
	}

	# Generate classes
	for my $class ( @{ $self->classes } ) {
		$code .= $class->generate_moosex_declare_code( $code_gen_options );
	}

	# Generate sample usage code
	if ($code_gen_options->{sample_code}) {
		$code .= "\npackage main;\n";
		my $count = 1;
		for my $class ( @{ $self->classes } ) {
			$code .= "my \$o$count = " . $class->name . "->new;\n";
			$count++;
		}
	}

	return $code;
}

sub provide_help {
	require Wx;
	return Wx::gettext('A program can contain multiple class, role definitions');
}

__PACKAGE__->meta->make_immutable;

1;
