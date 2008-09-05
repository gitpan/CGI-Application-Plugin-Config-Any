#!perl -T

use strict;
use warnings;

use Test::More tests => 7;

BEGIN {
	use_ok( 'CGI::Application::Plugin::Config::Any' );
}

{
    my $config = CGI::Application::Plugin::Config::Any->config();
    ok( $config, 'module loaded' );

    $config->init(
        'configdir' => './t',
        'files'     => [ 'basic.pl' ],
        'params'    => {
            'use_ext' => 1,
        },
    );
    
    ## check section()
    my $section = $config->section('Component');
    ok( ref $section eq 'HASH', 'section(\'Component\') shall return a hashref' );
    
    ## check param()
    ok( $config->param( 'name' ) eq 'TestApp', 'param(\'name\') shall return \'TestApp\'' );
    
    ## check deep => buried => key
    ok( $config->param( 'key' ) eq 'value', 'param(\'key\') shall return \'value\'' );
    
    ## check getall()
    my $cfg = $config->getall;
    ok( ref $cfg eq 'HASH', 'getall() shall return a hashref' );

    ## check for attribute 'name' in return value of getall()
    is( $cfg->{ name }, 'TestApp', 'expected key [name] was found and has the right content' );
}
