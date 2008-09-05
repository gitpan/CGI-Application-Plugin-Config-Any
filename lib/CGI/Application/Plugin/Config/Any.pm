## --------------------------------------------------------------------
## C::A::Plugin to use Config::Any
## --------------------------------------------------------------------

package CGI::Application::Plugin::Config::Any;
use strict;
use warnings;

=head1 NAME

CGI::Application::Plugin::Config::Any - Add Config::Any Support to CGI::Application

=head1 VERSION

Version 0.04

=cut

$CGI::Application::Plugin::Config::Any::VERSION = '0.04';
$CGI::Application::Plugin::Config::Any::DEBUG   = 0;

use base 'Exporter';
use vars '@EXPORT';
@EXPORT = qw( config );

use Config::Any;

=head1 SYNOPSIS

In your L<CGI::Application|CGI::Application>-based module:

    use base 'CGI::Application';
    use CGI::Application::Plugin::Config::Any;

    sub cgiapp_init {
        my $self = shift;

        # Set config file and other options
        $self->config->init(
            configdir => '/path/to/configfiles',
            files     => [ 'app.conf' ],
            name      => 'main',
            params    => {
                ## passed to Config::Any->load_files;
                ## see Config::Any for valid params
            }
        );
    }

Later...

    ## get a complete config section as a hashref
    $self->config->section( 'sectionname' );
    
    ## get a single config param
    $self->config->param( 'sectionname.paramname' );
    

=head1 DESCRIPTION

This module allows to use L<Config::Any|Config::Any> for config files inside a
CGI::Application based application.

B<This module is "work in progress" and subject to change without warning!>

(L<Config::Any|Config::Any> provides a facility for Perl applications and libraries
to load configuration data from multiple different file formats. It 
supports XML, YAML, JSON, Apache-style configuration, Windows INI 
files, and even Perl code.)

=cut


#-------------------------------------------------------------------
# METHOD:     _new
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  internal constructor (non public method)
#-------------------------------------------------------------------
sub _new {
    my $caller = shift;
    my $class  = ref($caller) || $caller;

    my %args   = ( @_ );

    my $set = {
        '__CONFIG_ANY_DIR'   => delete $args{'configdir'},
        '__CONFIG_ANY_FILES' => delete $args{'files'},
        '__CONFIG_ANY_NAME'  => delete $args{'name'},
    };
        
    my $self = bless $set, $class;
    
    return $self;
    
}   # --- end sub _new ---

=head1 METHODS

=head2 init

Initializes the plugin.

    $self->config->init(
        configdir => '/path/to/configfiles',
        files     => [ 'app.conf' ],
    );

Valid params:

=over 4

=item configdir SCALAR

Path where the config files reside in.

=item files ARRAY

A list of files to load.

=item name SCALAR

You can use more than one configuration at the same time by using config
names. For example:

    $self->config->init(
        name   => 'database',
        files  => [ 'db.conf' ],
    );
    $self->config->init(
        name   => 'template',
        files  => [ 'tpl.conf' ],
    );

    ...

    my $connection_options  = $self->config('database')->section('connection');
    my $template_config     = $self->config('template')->param('file');

=item params HASHREF

Options to pass to Config::Any->load_files().

B<Example:>

    $self->config->init(
        files  => [ 'default.yml' ],
        params => {
            'use_ext' => 1,
        }
    );

See L<Config::Any> for details.

=back

=cut

#-------------------------------------------------------------------
# METHOD:     init
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  
#-------------------------------------------------------------------
sub init {
    my $self = shift;
    
    my %args = (
        'name'      => $self->{'__CONFIG_ANY_NAME'}  || ref $self,
        'configdir' => $self->{'__CONFIG_ANY_DIR'}   || undef,
        'files'     => $self->{'__CONFIG_ANY_FILES'} || undef,
        'params'    => {},
        @_
    );
    
    $self->{'__CONFIG_ANY_DIR'}    = delete $args{'configdir'};
    $self->{'__CONFIG_ANY_FILES'}  = delete $args{'files'};
    $self->{'__CONFIG_ANY_NAME'}   = delete $args{'name'};
    $self->{'__CONFIG_ANY_PARAMS'} = delete $args{'params'};
    
    $CGI::Application::Plugin::Config::Any::DEBUG
        and $self->_debug(
              "initialized with:\n"
            . "\tname:      $self->{'__CONFIG_ANY_NAME'}\n"
            . "\tconfigdir: $self->{'__CONFIG_ANY_DIR'}\n"
            . "\tfiles:     "
            . join( ', ', @{ $self->{'__CONFIG_ANY_FILES'} } )
        );

    return 1;
    
}   # --- end sub init ---


=head2 config

This method is exported to your C::A based application as an accessor
to the configuration methods.

=cut

#-------------------------------------------------------------------
# METHOD:     config
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  
#-------------------------------------------------------------------
sub config {
    my $self = shift;
    my $conf = shift || ref $self;

    if ( $conf ) {
    
        if ( ! exists $self->{'__CONFIG_ANY_LOADED'}->{ $conf } ) {
        
            $self->{'__CONFIG_ANY_LOADED'}->{ $conf } 
                = CGI::Application::Plugin::Config::Any->_new( 
                    'name' => $conf, 
                    @_ 
                );
        }
        
        return $self->{'__CONFIG_ANY_LOADED'}->{ $conf };
        
    }    

    return CGI::Application::Plugin::Config::Any->_new(
        'name' => ref $self, 
        @_
    );

}   # --- end sub config ---


=head2 param

Retrieve a value from your configuration.

Examples:

    $self->config->section('mysection')->param('mysetting');
    # set the section to 'mysection' before retrieving 'mysetting'
    
    $self->config->param('mysetting','mysection');
    # more convenient way to do the same as above
    
    $self->config->param('mysection.mysetting');
    # another way to do the same as above
    
    $self->config->param('mysetting');
    # if no section name is given, the name of the last section
    # named by ->section() or ->param(<section>.<attribute>) syntax
    # is used; this may change in future, so don't rely on it!

=cut

#-------------------------------------------------------------------
# METHOD:     param
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  
#-------------------------------------------------------------------
sub param {
    my $self    = shift;
    my $param   = shift;
    my $section = shift;
    
    if ( $param =~ /^(.*)\.(.*)$/ ) {
        $section = $1;
        $param   = $2;
    }
    
    if ( ! $section && $self->{'__CURRENT_SECTION'} ) {
        $section = $self->{'__CURRENT_SECTION'};
    }
    
    $CGI::Application::Plugin::Config::Any::DEBUG
        and $self->_debug(
              "\nCGI::Application::Plugin::Config::Any\n"
            . "    loading param [$param]\n"
            . "          section [$section]\n"
        );
    
    return $self->_load(
        section => $section,
        param   => $param
    );
    
}   # --- end sub param ---


=head2 section

Retrieve a complete section from your configuration, or set the name
of the current "default section" for later use with ->param().

    my $hash = $self->config->section('mysection');

=cut

#-------------------------------------------------------------------
# METHOD:     section
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  
#-------------------------------------------------------------------
sub section {
    my $self    = shift;
    my $section = shift;
    
    $self->{'__CURRENT_SECTION'} = $section;
    
    $CGI::Application::Plugin::Config::Any::DEBUG
        and $self->_debug(
            "loading section [$section]"
        );
    
    return $self->_load( section => $section ) if defined wantarray;
    
    return;
    
}   # --- end sub section ---


=head2 getall

Get complete configuration as a hashref.

=cut

#-------------------------------------------------------------------
# METHOD:     getall
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  
#-------------------------------------------------------------------
sub getall {
    my $self = shift;
    
    return $self->_load();
    
}   # --- end sub getall ---


#-------------------------------------------------------------------
#               + + + + + INTERNAL METHODS + + + + +
#-------------------------------------------------------------------

#-------------------------------------------------------------------
# METHOD:     _load
# + author:   Bianka Martinovic
# + reviewed: 07-11-14 Bianka Martinovic
# + purpose:  load config file(s)
#-------------------------------------------------------------------
sub _load {
    my $self = shift;
    
    my %args = (
        section   => undef,
        param     => undef,
        @_
    );
      
    my %config = ();    
    
    ## config already loaded?
    unless ( $self->{'__CONFIG_ANY_CONFIG'}->{ $self->{'__CONFIG_ANY_NAME'} } ) {
    
        $CGI::Application::Plugin::Config::Any::DEBUG
            and $self->_debug(
                "loading config named [$self->{'__CONFIG_ANY_NAME'}]"
            );

        if ( $self->{'__CONFIG_ANY_FILES'} && ref $self->{'__CONFIG_ANY_FILES'} ne 'ARRAY' ) {
            $self->{'__CONFIG_ANY_FILES'} = [ $self->{'__CONFIG_ANY_FILES'} ];
        }
        
        $self->{'__CONFIG_ANY_FILES'} 
            = [ 
                map { $self->{'__CONFIG_ANY_DIR'}.'/'.$self->{'__CONFIG_ANY_FILES'}[$_] } 
                    0 .. $#{ $self->{'__CONFIG_ANY_FILES'} } 
              ];
    
        ## load the files using Config::Any
        my $cfg = Config::Any->load_files( 
                      { 
                          files   => $self->{'__CONFIG_ANY_FILES'}, 
                          %{ $self->{'__CONFIG_ANY_PARAMS'} }
                      }
                  );
    
        ## import settings
        for ( @$cfg ) {
        
            my ( $filename, $thisconfig ) = each %$_;
            
            foreach ( keys %$thisconfig ) {
                $config{$_} = $thisconfig->{$_};
            }
        
        }
    
        $self->{'__CONFIG_ANY_CONFIG'}->{ $self->{'__CONFIG_ANY_NAME'} } = \%config;
        
    }
    else {
        %config = %{ $self->{'__CONFIG_ANY_CONFIG'}->{ $self->{'__CONFIG_ANY_NAME'} } };
    }

    ## return a section
    if ( $args{'section'} && ! $args{'param'} ) {
    
        $CGI::Application::Plugin::Config::Any::DEBUG
            and $self->_debug(
                "returning complete section [$args{'section'}]"
            );
    
        return $config{ $args{'section'} };
    
    }

    if ( $args{'param'} ) {
    
        my $value = $config{ $args{'param'} }
                 || $config{ $args{'section'} }->{ $args{'param'} };
                 
        unless ( defined $value ) {
            $CGI::Application::Plugin::Config::Any::DEBUG
                and $self->_debug(
                    "trying to find key [$args{'param'}]"
                );
            $value = $self->_find_key( $args{'param'}, \%config );
        }

        return $value;

    }

    return \%config;# unless wantarray;
    
}   # --- end sub _load ---

#-------------------------------------------------------------------
# METHOD:     _find_key
# + author:   Bianka Martinovic
# + reviewed: Bianka Martinovic
# + purpose:  find a key in the config data structure
#-------------------------------------------------------------------
sub _find_key {
    my $self   = shift;
    my $key    = shift;
    my $config = shift;

    unless ( ref $config eq 'HASH' ) {
        return;
    }
    
    if ( exists $config->{ $key } ) {
        return $config->{ $key };
    }
    
    foreach my $subkey ( keys %{ $config } ) {
        my $value = $self->_find_key( $key, $config->{$subkey} );
        return $value if $value;
    }
    
    return;

}   # --- end sub _find_key ---


=pod

=head1 DEBUGGING

This module provides some internal debugging. Any debug messages go to
STDOUT, so beware of enabling debugging when running in a web
environment. (This will end up with "Internal Server Error"s in most
cases.)

There are two ways to enable the debug mode:

=over 4

=item In the module

Find line

    $CGI::Application::Plugin::Config::Any::DEBUG = 0;

and set it to any "true" value. ("1", "TRUE", ... )

=item From outside the module

Add this line B<before> calling C<new>:

    $CGI::Application::Plugin::Config::Any::DEBUG = 1;

=back

=cut

#-------------------------------------------------------------------
# METHOD:     _debug
# + author:   Bianka Martinovic
# + reviewed: 07-11-14 Bianka Martinovic
# + purpose:  print out formatted _debug messages
#-------------------------------------------------------------------
sub _debug {
    my $self = shift;
    my $msg  = shift;
    
    my $dump;
    if ( @_ ) {
        if ( scalar ( @_ ) % 2 == 2 ) {
            %{ $dump } = ( @_ );
        }
        else {
            $dump = \@_;
        }
    }
    
    my ( $package, $line, $sub ) = (caller())[0,2,3];
    my ( $callerpackage, $callerline, $callersub ) 
        = (caller(1))[0,2,3]; 
    
    $sub ||= '-';
    
    print "\n",
          join( ' | ', $package, $line, $sub ),
          "\n\tcaller: ",
          join( ' | ', $callerpackage, $callerline, $callersub ),
          "\n\t$msg",
          "\n\n";
    
    #if ( $dump ) {
    #    print $self->_dump( $dump );
    #}
    
    return;
}   # --- end sub _debug ---

1;

__END__


=head1 AUTHOR

Bianka Martinovic, C<< <mab at cpan.org> >>

=head1 BUGS/CAVEATS

B<This module is "work in progress" and subject to change without warning!>

=head2 Complex data structures

At the moment, there is no way to require a key buried deep in the config
data structure. Example for a more complex data structure (YAML syntax):

    database_settings:
        dsn: dbi:mysql:cm4web2:localhost
        driver: mysql
        host: localhost
        port: 3306
        additional_args:
            ShowErrorStatement: 1

You can not require the key 'ShowErrorStatement' directly, 'cause it's a
subkey of 'additional_args', but the C<param()> method does not support
nested section names.

Anyway, if CAP::Config::Any isn't able to find a required key in the current
section, it walks through the complete config data structure to find it. So,
the following works with this example:

    my $param = $self->config->param('ShowErrorStatement');
    ## this will return '1'

There is no way to suppress this at the moment, so beware of having similar
named keys in different sections of your configuration! You may not get what
you expected.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CGI::Application::Plugin::Config::Any

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CGI-Application-Plugin-Config::Any>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CGI-Application-Plugin-Config::Any>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CGI-Application-Plugin-Config::Any>

=item * Search CPAN

L<http://search.cpan.org/dist/CGI-Application-Plugin-Config::Any>

=back
    
=head1 DEPENDENCIES

=over 8

=item Config::Any

=back

=head1 ACKNOWLEDGEMENTS

This module was slightly inspired by C<CGI::Application::Plugin::Context>.
See L<http://search.cpan.org/perldoc?CGI::Application::Plugin::Config::Context>
for details.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Bianka Martinovic, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
