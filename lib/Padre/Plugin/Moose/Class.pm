package Padre::Plugin::Moose::Class;

use namespace::clean;
use Moose;

has 'name'         => ( is => 'rw', isa => 'Str', default => '' );
has 'extends_list' => ( is => 'rw', isa => 'Str', default => '' );
has 'roles_list'   => ( is => 'rw', isa => 'Str', default => '' );
has 'attributes'   => ( is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has 'subtypes'     => ( is => 'rw', isa => 'ArrayRef', default => sub { [] }  );
has 'immutable'    => ( is => 'rw', isa => 'Bool'  );
has 'namespace_autoclean'    => ( is => 'rw', isa => 'Bool'  );

sub to_code {
	my $self = shift;
	my $comments = shift;

	my $class = $self->name;
	my $superclass = $self->extends_list;
	my $roles = $self->roles_list;
	my $namespace_autoclean = $self->namespace_autoclean;
	my $make_immutable = $self->immutable;

	$class =~ s/^\s+|\s+$//g;
	$superclass =~ s/^\s+|\s+$//g;
	$roles =~ s/^\s+|\s+$//g;
	my @roles = split /,/, $roles;

	# if($class eq '') {
		# $self->main->error(Wx::gettext('Class name cannot be empty'));
		# $self->{class_text}->SetFocus();
		# return;
	# }

	my $code = "package $class;\n";

	if($namespace_autoclean) {
		$code .= "\nuse namespace::clean;";
		$code .= $comments
			? " # Keep imports out of your namespace\n"
			: "\n";
	}

	$code .= "\nuse Moose;";
	$code .= $comments
		? " # automatically turns on strict and warnings\n"
		: "\n";
	$code .= "\nextends '$superclass';\n" if $superclass ne '';

	$code .= "\n" if scalar @roles;
	for my $role (@roles) {
		$code .= "with '$role';\n";
	}

	if($make_immutable) {
		$code .= "\n__PACKAGE__->meta->make_immutable;";
		$code .= $comments
			? " # Makes it faster at the cost of startup time\n"
			: "\n";
	}
	$code .= "\n1;\n\n";

	return $code;
}

__PACKAGE__->meta->make_immutable;

1;
