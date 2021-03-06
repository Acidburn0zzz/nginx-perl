package Nginx;

our $VERSION = '1.2.9.7';

use strict;
use warnings;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(

    ngx_http_time
    ngx_http_cookie_time
    ngx_http_parse_time
    ngx_escape_uri
    ngx_prefix
    ngx_conf_prefix

    ngx_log_error
    ngx_log_notice
    ngx_log_info
    ngx_log_crit
    ngx_log_alert

    ngx_timer
    ngx_resolver
    ngx_connector
    ngx_ssl_handshaker
    ngx_reader
    ngx_writer
    ngx_read
    ngx_write
    ngx_close
    ngx_ssl_handshake
    ngx_noop

    NGX_READ
    NGX_WRITE
    NGX_CLOSE
    NGX_SSL_HANDSHAKE
    NGX_NOOP
    NGX_EOF
    NGX_EINVAL
    NGX_ENOMEM
    NGX_EBADE
    NGX_EBADF
    NGX_ENOMSG
    NGX_EAGAIN
    NGX_ETIMEDOUT

    NGX_RESOLVE_FORMERR
    NGX_RESOLVE_SERVFAIL
    NGX_RESOLVE_NXDOMAIN
    NGX_RESOLVE_NOTIMP
    NGX_RESOLVE_REFUSED
    NGX_RESOLVE_TIMEDOUT

    NGX_DONE
    NGX_OK
    NGX_HTTP_LAST

    NGX_ESCAPE_URI
    NGX_ESCAPE_ARGS
    NGX_ESCAPE_URI_COMPONENT
    NGX_ESCAPE_HTML
    NGX_ESCAPE_REFRESH
    NGX_ESCAPE_MEMCACHED
    NGX_ESCAPE_MAIL_AUTH

    OK
    DECLINED

    HTTP_OK
    HTTP_CREATED
    HTTP_ACCEPTED
    HTTP_NO_CONTENT
    HTTP_PARTIAL_CONTENT

    HTTP_MOVED_PERMANENTLY
    HTTP_MOVED_TEMPORARILY
    HTTP_REDIRECT
    HTTP_NOT_MODIFIED

    HTTP_BAD_REQUEST
    HTTP_UNAUTHORIZED
    HTTP_PAYMENT_REQUIRED
    HTTP_FORBIDDEN
    HTTP_NOT_FOUND
    HTTP_NOT_ALLOWED
    HTTP_NOT_ACCEPTABLE
    HTTP_REQUEST_TIME_OUT
    HTTP_CONFLICT
    HTTP_GONE
    HTTP_LENGTH_REQUIRED
    HTTP_REQUEST_ENTITY_TOO_LARGE
    HTTP_REQUEST_URI_TOO_LARGE
    HTTP_UNSUPPORTED_MEDIA_TYPE
    HTTP_RANGE_NOT_SATISFIABLE

    HTTP_INTERNAL_SERVER_ERROR
    HTTP_SERVER_ERROR
    HTTP_NOT_IMPLEMENTED
    HTTP_BAD_GATEWAY
    HTTP_SERVICE_UNAVAILABLE
    HTTP_GATEWAY_TIME_OUT
    HTTP_INSUFFICIENT_STORAGE
);

require XSLoader;
XSLoader::load('Nginx', $VERSION);

1;
__END__

=head1 NAME

Nginx - full-featured perl support for nginx

=head1 SYNOPSIS

    use Nginx;
    
    # nginx's asynchronous resolver
    #     "resolver 1.2.3.4;" in nginx-perl.conf
    
    ngx_resolver "www.google.com", 15, sub {
        my (@IPs) = @_;
        
        if ($!) {
            my ($errcode, $errstr) = @_;
            ngx_log_error $!, "Cannot resolve google's IP: $errstr";
        }
    };
    
    # timer
    
    ngx_timer 5, 0, sub {
        ngx_log_notice 0, "5 seconds gone";
    };
    
    # asynchronous connections
    # with explicit flow control
    
    ngx_connector "1.2.3.4", 80, 15, sub {
        if ($!) {
            ngx_log_error $!, "Connect error: $!";
            return NGX_CLOSE;
        }
        
        my $c = shift;  # connection
        my $wbuf = "GET /\x0d\x0a";
        my $rbuf;
        
        ngx_writer $c, $wbuf, 15, sub {
            if ($!) {
                ngx_log_error $!, "Write error: $!";
                return NGX_CLOSE;
            }
            
            return NGX_READ;
        };
        
        ngx_reader $c, $rbuf, 0, 0, 15, sub {
            if ($! && $! != NGX_EOF) { 
                ngx_log_error $!, "Read error: $!";
                return NGX_CLOSE;
            }
            
            if ($! == NGX_EOF) {
                ngx_log_info 0, "response length: " . length ($rbuf);
                return NGX_CLOSE;
            }
            
            return NGX_READ;  # no errors - read again
        };
        
        return NGX_WRITE;  # what to do on connect
    };
    
    # SSL handshake
    
    ngx_connector "1.2.3.4", 80, 15, sub {
        ...
        my $c = shift;
        
        ngx_ssl_handshaker $c, 15, sub {
            ...
            ngx_writer $c, $wbuf, 15, sub {
                ...
            };
            
            ngx_reader $c, $rbuf, 0, 0, 15, sub {
                ...
            };
            
            return NGX_WRITE;
        };
        
        return NGX_SSL_HANDSHAKE;
    };
    
    # asynchronous response
    # via HTTP API
    
    sub handler {
        my ($r) = shift;
        
        $r->main_count_inc;
        
        ngx_resolver "www.google.com", 15, sub {
            
            $r->send_http_header ('text/html');
            
            unless ($!) {
                lcoal $, = ', ';
                $r->print ("OK, @_\n");
            } else {
                $r->print ("FAILED, $_[1]\n");
            }
            
            $r->send_special (NGX_HTTP_LAST);
            $r->finalize_request (NGX_OK);
        };
         
        return NGX_DONE;
    }
    
    # and more... 

F<nginx-perl.conf>:

    http {
        
        perl_inc      /path/to/lib;
        perl_inc      /path/to/apps;
        perl_require  My/App.pm;
        
        perl_init_worker  My::App::init_worker;
        perl_exit_worker  My::App::exit_worker;
        
        perl_eval  '$My::App::SOME_VAR = "foo"';
        ...
        
        server {
            location / {
                perl_handler  My::App::handler;
        ...

F<My/App.pm>:

    package My::App;
    
    use Nginx;
    
    sub handler {
        my $r = shift;
        ...
    }
    ...

=head1 DESCRIPTION

Nginx with capital I<N> is a part of B<nginx-perl> distribution.

Nginx-perl brings asynchronous functions and other useful features 
into embedded perl to turn it into nice and powerful perl web server.

=head1 RATIONALE

Nginx is very popular and stable asynchronous web-server.
And reusing as much of its internals as possible gives this project 
same level of stability nginx has. Maybe not right from the beginning,
but it can catch up with a very little effort.

Internal HTTP parser, dispatcher (locations) and different types
of handlers free perl modules from reinventing all that, like most 
of the perl frameworks do. It's already there, native and extremely
fast. 

All of the output filters there as well and everything you do
can be gzipped, processed with xslt or through any filter module
for nginx. Again, extremely fast.

Nginx has a pretty decent master-worker model, which allows to do
process management right out of the box.

And probably some other things I can't remember at the moment.

So, why use any of those perl frameworks if we already have 
nginx with nice native implementation for almost everything
they offer. It just needed a little touch.

Additionally I wanted to implement new asynchronous API
with proper flow control and explicit parameters to avoid
complexity as much as possible. 

=head1 INSTALLATION

As usual for perl extensions:

    % perl Makefile.PL
    % make
    % make test
    % make install

F<Makefile.PL> supports everything F<./configure> does. 
To build it with SSL support use something like:

    % perl Makefile.PL --with-http_ssl_module

Or if you want to install it into different perl simply run F<Makefile.PL>
undef it:

    % /home/zzz/perl5/perlbrew/perls/perl-5.14.2/bin/perl Makefile.PL

It is safe to install nginx-perl alongside nginx. It uses 
capital B<N> for perl modules and F<nginx-perl> for binaries.

=head1 RUNNING EXAMPLES

You don't have to install nginx-perl to try it. There are couple
of ready to try examples in F<eg/>:

    % ./objs/nginx-perl -p eg/helloworld

Now open another terminal or your web browser and go to
http://127.0.0.1:55555/ or whatever IP you're on.

=head1 BENCHMARKING

The easiest way to benchmark nginx-perl against node.js is to run
redis example from F<eg/redis>, F<eg/redis.js> and compare the results. 
But first you need to install L<Redis::Parser::XS> from cpan:

    % cpan Redis::Parser::XS
    ...
    % ./objs/nginx-perl -p eg/redis
    ...

    % ab -c10 -n10000 http://127.0.0.1:55555/
    % ab -c10 -n10000 http://127.0.0.1:55555/single
    % ab -c10 -n10000 http://127.0.0.1:55555/multi

Same goes for node.js:

    % npm install redis
    % npm install hiredis
    ...
    % node eg/redis.js
    ...

    % ab -c10 -n10000 http://127.0.0.1:55555/
    % ab -c10 -n10000 http://127.0.0.1:55555/single
    % ab -c10 -n10000 http://127.0.0.1:55555/multi

=head1 CONFIGURATION DIRECTIVES

=over 4

=item perl_inc  /path/to/lib;

Works just like Perl's C<use lib '/path/to/lib'>. Supports only one
argument, but you can specify it multiple times.

    http {
        perl_inc  /path/to/lib;
        perl_inc  /path/to/myproject/lib;


=item perl_require  My/App.pm;

Same as Perl's own C<require>.

    http {
        perl_inc      /path/to/lib;
        perl_require  My/App.pm;

=item perl_init_worker  My::App::init_worker;

Adds a handler to call on worker's start.

    http {
        perl_inc          /path/to/lib;
        perl_require      My/App.pm;
        
        perl_init_worker  My::App::init_worker;
        perl_init_worker  My::AnotherApp::init_worker;

=item perl_exit_worker  My::App::exit_worker;

Adds a handler to call on worker's exit.

    http {
        perl_inc          /path/to/lib;
        perl_require      My/App.pm;
        
        perl_exit_worker  My::App::exit_worker;
        perl_exit_worker  My::AnotherApp::exit_worker;

=item perl_handler  My::App::handler; 

Sets current location's http content handler (a.k.a. http handler).

    http {
        server {
            location / {
                perl_handler My::App::Handler;


=item perl_access  My::App::access_handler; 

Adds an http access handler to the access phase of current location.

    http {
        server {
            location / {
                perl_access My::App::access_handler; 
                perl_handler My::App::Handler;

=item perl_eval  '$My::App::CONF{foo} = "bar"';

Evaluates some perl code on configuration level. Useful if you 
need to configure some perl modules directly fron F<nginx-perl.conf>.

    http {
        perl_eval  '$My::App::CONF{foo} = "bar"';

=item perl_app  /path/to/app.pl;

Sets http content handler to the C<sub { }> returned from
the app. Internally does simple C<$handler = do '/path/to/app.pl'>,
so you can put your app into @INC somewhere to get shorter path.
Additionally prereads entire request body before calling the handler.
Which means there is no need to call $r->has_request_body there.

    http {
        server {
            location / {
                perl_app  /path/to/app.pl;

=back

=head1 INTERNAL FUNCTIONS

=head3 C<< ngx_escape_uri $uri, $type >>;

Escapes C<$uri> using internal function ngx_escape_uri() from 
F<src/core/ngx_string.c>. If C<$type> is specified, uses it or 
NGX_ESCAPE_URI otherwise. Returns escaped uri on success or 
undef on error;

    my $foo = ngx_escape_uri 'a b';
      # gives 'a%20b'
    
    my $foo = ngx_escape_uri 'a b', NGX_ESCAPE_URI;

Type defines what characters to escape:

    NGX_ESCAPE_URI                " ", "#", "%", "?", 
                                  %00-%1F, %7F-%FF
                                 
    NGX_ESCAPE_ARGS               " ", "#", "%", "&", "+", "?", 
                                  %00-%1F, %7F-%FF 
                                 
    NGX_ESCAPE_URI_COMPONENT      everything except: 
                                   ALPHA, DIGIT, "-", ".", "_", "~"
                                 
    NGX_ESCAPE_HTML               " ", "#", """, "%", "'", 
                                  %00-%1F, %7F-%FF
                                 
    NGX_ESCAPE_REFRESH            " ", """, "%", "'", 
                                  %00-%1F, %7F-%FF
                                 
    NGX_ESCAPE_MEMCACHED          " ", "%", %00-%1F

=head3 C<< ngx_http_time $time >>

Returns C<$time> in HTTP format. Uses internal function ngx_http_time()
from F<src/core/ngx_times.c>.

    my $tomorrow = ngx_http_time time + 86400;
        # $tomorrow = 'Tue, 03 Apr 2012 20:14:41 GMT';

=head3 C<< ngx_http_cookie_time $time >>

Returns C<$time> in HTTP format suitable for Set-Cookie header. Uses 
internal function ngx_http_cookie_time() from F<src/core/ngx_times.c>.

    my $tomorrow = ngx_http_time time + 86400;
        # $tomorrow = 'Tue, 03-Apr-12 20:14:41 GMT';

=head3 C<< ngx_http_parse_time $str >>

Parses C<$str> and returns timestamp. On error returns C<undef>. Uses
internal function ngx_http_parse_time() from F<src/http/ngx_http_parse_time.c>.

    my $time = ngx_http_parse_time "Thu, 01 Jan 1970 00:00:00 GMT"
        or die "Cannot parse time\n";
    
          # $time = '0'

=head1 HTTP API

=head2 CONTENT HANDLER

This is where response should get generated and send to the client.
Here's how to send response completely asynchronously:

    sub handler {
        my $r = shift;
        
        $r->main_count_inc;
        
        ngx_timer 1, 0, sub {
            $r->send_http_header('text/html');
            $r->print("OK\n");
            
            $r->send_special(NGX_HTTP_LAST);
            $r->finalize_request(NGX_OK);
        };
        
        return NGX_DONE;
    }

Notice C<return NGX_DONE> instead of C<return OK>, this is important,
because it allows to avoid post processing response the old way.

=head2 ACCESS HANDLER

Access handler is a perfect place for access control. Return C<NGX_OK>
to allow access or some HTTP error to deny:

    sub access_handler {
        my ($r) = @_;
        
        if ($r->uri eq '/private') {
            return 403;
        }
        
        return NGX_OK;
    }

It is also possible to do something asynchronously, as with content handler,
but a bit differently. On success we have to pass request to the next
phase handler but finalize it on error. As before, C<NGX_DONE> means 
that we are going to process request ourselves. So, let's rewrite first 
example but make it suitable for asynchronous execution:

    sub access_handler {
        my ($r) = @_;
        
        if ($r->uri eq '/private') {
            $r->finazlie_request(403);
            return NGX_DONE;
        }
        
        $r->phase_handler_inc;
        $r->core_run_phases;
        return NGX_DONE;
    }

Now it is possible to use timer or redis client or any other asynchronous
function:

    sub access_handler {
        my ($r) = @_;
        
        ngx_timer 1, 0, sub {
            
            if ($r->uri eq '/private') {
                $r->finalize_request(403);
                return;
            } 
            
            $r->phase_handler_inc;
            $r->core_run_phases;
        };
        
        return NGX_DONE;
    }

One of the interesting things you can do with it is putting username into 
internal variable:

    sub access_handler {
        my ($r) = @_;
        
        ngx_timer 1, 0, sub {
            
            $r->variable("my_username", "foobar");
            
            $r->phase_handler_inc;
            $r->core_run_phases;
        };
        
        return NGX_DONE;
    }

It allows you to pass this variable to the upstream as a header
or use it in any other way in configuration:

    server {
        set $my_username "guest";
        
        location / {
            perl_access  Foo::access_handler;
            
            proxy_pass        http://1.2.3.4:5678; 
            proxy_set_header  X-My-Username  $my_username;
        }
    }

Be aware that nginx might call access handler more than once depending
on your configuration. And if you are using redis for this you should
consider caching reply even for a little time.

=head2 METHODS

Most of the following methods are available for both original embedded perl
and nginx-perl. 

=head3 C<< $r->status($status) >>

Sets response status. 

    $r->status(404);

=head3 C<< $r->send_http_header($content_type) >>

Sends http headers of the response. If C<$content_type> is given sets
content type of the response.

    $r->send_http_header("text/html; charset=UTF-8");

=head3 C<< $r->header_only >>

Returns true if client expects only header of the response, e.g. HEAD request.

    unless ($r->header_only) {
        $r->print("hello world");
    }

=head3 C<< $r->uri >>

Returns normalized uri of the request without query string. Unparsed uri
available through either new method C<< $r->unparsed_uri >> or internal
variable C<< $r->variable("request_uri") >>.

=head3 C<< $r->args >>

This is just a query string. 

=head3 C<< $r->request_method >>

Returns HTTP request method. As usual GET, HEAD, POST, etc.

=head3 C<< $r->remote_addr >>

Returns textual representation of remote address.

=head3 C<< $ctx = $r->ctx($ctx) >>

Sets and gets some context scalar. It will be useful to get some data 
from access handler for example.

=head3 C<< $r->location_name >>

Returns the name of the location. 

    location /foo {
        perl_handler ...;
    }

    my $loc = $r->location_name;    
    # $loc = '/foo'

=head3 C<< $r->root >>

Returns the root path.

=head3 C<< $r->header_in("User-Agent") >>

Returns desired HTTP header. Case doesn't matter. If you want to get
all of the headers take a look at one of the new methods: 
C<< $r->headers_in >>.

=head3 C<< $r->headers_in >>

Returns all headers in the following form:

    {  content-type   => ['text/html'],
       content-length => [1234]          }

=head3 C<< $r->has_request_body(\&handler) >>

Returns true if there is a request body to be read and sets the handler 
to call when done or false otherwise. And if there is a body you should
return from current handler and continue in the new one. 

    sub handler {
        my ($r) = @_;
        
        if ( $r->has_request_body(\&handler_with_body) ) {
            return OK;
        }
        
        ...
    }

    sub handler_with_body {
        my ($r) = @_;
        
        my $body = $r->request_body;
        ...
    }

=head3 C<< $r->preread >>

Returns part of the body already present in the header's buffer or undef
otherwise. 

=head3 C<< $r->request_body >>

Returns request body if it is stored in memory or undef otherwise.
By default request body will be read into memory if it is less than 
C<client_body_buffer_size> and C<client_max_body_size>. You can change
them in F<nginx-perl.conf>.

=head3 C<< $r->request_body_file >>

If request body doesn't fit into C<client_body_buffer_size> it is stored
in temporary file. You can read it yourself.

    sub handler_with_body {
        my ($r) = @_;
        my $filename = $r->request_body_file;
        
        if (open $fh, '<', $filename) {
            ...
        }
    }

=head3 C<< $r->discard_request_body >>

Tells nginx to ignore request body. 

=head3 C<< $r->header_out($name, $value) >>

Adds HTTP header C<"$name: $value"> to the response.

=head3 C<< $r->filename >>

Returns the name of the file translated from URI. 

=head3 C<< $r->print($data, ...) >>

Sends C<$data> to the client. Make sure to send HTTP header before
you use this function.

=head3 C<< $r->sendfile($filename, $offset, $length) >>

Kind of like print, buf sends a static file instead. If C<$offset> and
C<$length> are specified uses them. Actual sending happens later.

If you have C<sendfile on;> in your F<nginx-perl.conf> it will bypass
output filters like gzip.

=head3 C<< $r->flush >>

Forces nginx to start sending data to the client.

=head3 C<< $r->internal_redirect($uri) >>

Performs internal redirect to C<$uri>. You can use it with original handler
only, i.e. you have to return C<OK> after this call. 

It might change in the future.

=head3 C<< $r->allow_ranges >>

Allows nginx to handle byte ranges in the response.

=head3 C<< $r->unescape($data) >>

Unescapes URI escaped data (C<"%XX">). 

=head3 C<< $r->variable($name, $value) >>

Gets and sets internal variables, the ones that you can see in config.

=head3 C<< $r->log_error($errno, $message) >>

Logs error message using current connection's log. 

=head3 C<< $r->main_count_inc() >>

Increases value of an internal C<< r->main->count >> by 1 and
therefore allows to send response later from some other callback.

=head3 C<< $r->send_special($rc) >>

Sends response in a special way. We are using this function
to send response asynchronously from non-http handlers.

    ngx_timer 1, 0, sub {
        $r->send_http_header('text/html');
        $r->print("OK\n");
        
        $r->send_special(NGX_HTTP_LAST);
        $r->finalize_request(NGX_OK);
    };

=head3 C<< $r->finalize_request($rc) >>

Decreases C<< r->main->count >> and finalizes request.

=head3 C<< $r->phase_handler_inc() >>

Allows to move to the next phase handler from access handler.

=head3 C<< $r->core_run_phases() >>

Allows to break out of access handler and continue later from
some other callback.

=head1 ASYNCHRONOUS API

=head2 NAMING

    NGX_FOO_BAR  -- constants
    ngx_*r       -- asynchronous functions (creators)
    NGX_VERB     -- flow control constants 
    ngx_verb     -- flow control functions
    $r->foo_bar  -- request object's methods

Each asynchronous function has an B<r> at the end of its name. This is 
because those functions are creators of handlers with some parameters. 
E.g. ngx_writer creates write handler for some connection with some
scalar as a buffer.

=head2 FLOW CONTROL

To specify what to do after each callback we can either call some 
function or return some value and let handler do it for us. 
Most of the ngx_* handlers support return value and even optimized
for that kind of behavior.

Functions take connection as an argument:

    ngx_read($c)
    ngx_write($c)
    ngx_ssl_handshake($c)
    ngx_close($c)

Return values only work on current connection:

    return NGX_READ;
    return NGX_WRITE;
    return NGX_SSL_HANDSHAKE;
    return NGX_CLOSE;

As an example, let's connect and close connection. We will do flow control 
via single C<return> for this:

    ngx_connector '1.2.3.4', 80, 15, sub {
        
        return NGX_CLOSE;
    };

Now, if we want to connect and then read exactly 10 bytes we need
to create reader and C<return NGX_READ> from connector's callback:

    ngx_connector '1.2.3.4', 80, 15, sub {
        
        my $c = shift;
        
        ngx_reader $c, $buf, 10, 10, 15, sub {
            ... 
        };
        
        return NGX_READ;
    };

This will be different, if we already have connection somehow:

    ngx_reader $c, $buf, 10, 10, 15, sub {
        ... 
    };
    
    ngx_read($c);

=head2 ERROR HANDLING

Each ngx_* handler will call back on any error with C<$!> set to some value
and reset to 0 otherwise. 
For simplicity EOF considered to be an error as well and C<$!> will be set
to NGX_EOF in such case. 

Example:

    ngx_reader $c, $buf, 0, 0, sub {
        
        return NGX_WRITE
            if $! == NGX_EOF;
        
        return NGX_CLOSE
            if $!;
        ...
    };

=head2 FUNCTIONS

=head3 C<< ngx_timer $after, $repeat, sub { }; >>

Creates new timer and calls back after C<$after> seconds.
If C<$repeat> is set reschedules the timer to call back again after 
C<$repeat> seconds or destroys it otherwise.

Internally C<$repeat> is stored as a refence, so changing it will influence
rescheduling behaviour.

Simple example calls back just once after 1 second:

    ngx_timer 1, 0, sub {
        warn "tada\n";
    };

This one is a bit trickier, calls back after 5, 4, 3, 2, 1 seconds 
and destroys itself:

    my $repeat = 5;
    
    ngx_timer $repeat, $repeat, sub {
        $repeat--;
    };

=head3 C<< ngx_connector $ip, $port, $timeout, sub { }; >>

Creates connect handler and attempts to connect to C<$ip:$port> within 
C<$timeout> seconds. Calls back with connection in C<@_> afterwards. 
On error calls back with C<$!> set to some value.

Expects one of the following control flow constants as a result of callback: 

    NGX_CLOSE
    NGX_READ 
    NGX_WRITE
    NGX_SSL_HANDSHAKE

Additionally returns connection, if you need one. However, it might be a C<0>
on some errors, make sure to check it's not if you are planning to use it
with flow control functions.

Example:

    ngx_connector $ip, 80, 15, sub {
        
        return NGX_CLOSE
            if $!;
        
        my $c = shift;
        ...
        
        return NGX_READ;
    };

=head3 C<< ngx_reader $c, $buf, $min, $max, $timeout, sub { }; >>

Creates read handler for connection C<$c> with buffer C<$buf>.
C<$min> indicates how much data should be present in C<$buf> 
before the callback and C<$max> limits total length of C<$buf>.

Internally C<$buf>, C<$min>, C<$max> and C<$timeout> are stored
as refernces, so you can change them at any time to influence
reader's behavior.

Expects one of the following control flow constants as a result of callback: 

    NGX_CLOSE
    NGX_READ 
    NGX_WRITE
    NGX_SSL_HANDSHAKE

On error calls back with C<$!> set to some value, including 
NGX_EOF in case of EOF. 

    my $buf;
    
    ngx_reader $c, $buf, $min, $max, $timeout, sub {
        
        return NGX_CLOSE
            if $! && $! != NGX_EOF;
        ...
        
        return NGX_WRITE;
    };

Be aware, that C<$min> and C<$max> doesn't apply to the amount of data
you want to read but rather to the appropriate buffer size to call back with.

=head3 C<< ngx_writer $c, $buf, $timeout, sub { }; >>

Creates write handler for connection C<$c> with buffer C<$buf> and 
write timeout in <$timeout>.

Internally C<$buf> and C<$timeout> are stored as references, so 
changing them will influence writer's behavior. 

Expects one of the following control flow constants as a result of callback: 

    NGX_CLOSE
    NGX_READ 
    NGX_WRITE
    NGX_SSL_HANDSHAKE

On error calls back with C<$!> set to some value. NGX_EOF should be
treated as fatal error here. 

Example:

    my $buf = "GET /\n";
    
    ngx_writer $c, $buf, 15, sub {
        
        return NGX_CLOSE
            if $!;
        ...
        
        return NGX_READ;
    };

=head3 C<< ngx_ssl_handshaker $c, $timeout, sub { }; >>

Creates its own internal handler for both reading and writing and tries 
to do SSL handshake. 

Expects one of the following control flow constants as a result of callback: 

    NGX_CLOSE
    NGX_READ 
    NGX_WRITE
    NGX_SSL_HANDSHAKE

On error calls back with C<$!> set to some value. 

It's important to understand that handshaker will replace your previous 
reader and writer, so you have to create new ones.

Typically it should be called inside connector's callback:

    ngx_connector ... sub {
        
        return NGX_CLOSE 
            if $!;
        
        my $c = shift;
        
        ngx_ssl_handshaker $c, 15, sub {
            
            return NGX_CLOSE
                if $!;
            ...
            
            ngx_writer ... sub { };
            
            ngx_reader ... sub { };
            
            return NGX_WRITE;
        };
        
        return NGX_SSL_HANDSHAKE;
    };

=head3 C<< ngx_resolver $name, $timeout, sub { }; >>

Creates resolver's handler and tries to resolve C<$name> in C<$timeout>
seconds using resolver specified in F<nginx-perl.conf>.

On success returns all resolved IP addresses into C<@_>.

On error calls back with C<$!> set to some value, $_[0] set to one of the
resolver-specific error constants and with textual explanation in $_[1]:

    NGX_RESOLVE_FORMERR
    NGX_RESOLVE_SERVFAIL
    NGX_RESOLVE_NXDOMAIN
    NGX_RESOLVE_NOTIMP
    NGX_RESOLVE_REFUSED
    NGX_RESOLVE_TIMEDOUT

This is a thin wrapper around nginx's internal resolver.
All its current problems apply. To use it in production you'll need
a local resolver, like named that does actual resolving.

    ngx_resolver $host, $timeout, sub {
        
        if ($!) {
            my $errcode = $_[0];
            my $errstr  = $_[1];
            
            warn "failed to resolve $host: $errstr\n";
            ...
            
            return;
        }
        
        my @IPs = @_; # list of all resolved IP addresses
        ...
    };

=head1 CONNECTION TAKEOVER

It is possible to takeover client connection completely and create
you own reader and writer on that connection. 
You need this for websockets and protocol upgrade in general.

=head2 METHODS

There are two methods to support this:

=head3 C<< $r->take_connection >>

C<< $r->take_connection >> initializes internal data structure and 
replaces connection's data with it. Returns connection on success
or C<undef> on error.

    my $c = $r->take_connection;

=head3 C<< $r->give_connection >>

C<< $r->give_connection >> attaches request C<$r> back to its connection.
Doesn't return anything.

=head2 TAKEOVER

So, to takeover you need to take connection from the request, 
tell nginx that you are going to finalize it later by calling 
C<< $r->main_count_inc >>, create reader and/or writer on that
connection, start reading and/or writing flow and return NGX_DONE
from your HTTP handler:

    sub handler {
        my $r = shift;
        
        my $c = $r->take_connection()
            or return HTTP_SERVER_ERROR;
            
        $r->main_count_inc;
            
            my $buf;
            
            ngx_reader $c, $buf, ... , sub {
                
                if ($!) {
                    $r->give_connection;
                    $r->finalize_request(NGX_DONE);
                    
                    return NGX_NOOP;
                }
                
                ...
            };
            
            ngx_writer $c, ... , sub {
                
                if ($!) {
                    $r->give_connection;
                    $r->finalize_request(NGX_DONE);
                    
                    return NGX_NOOP;
                }
                
                ...
            };
            
            ngx_read($c);
        
        return NGX_DONE;
    }

Once you are done with the connection or connection failed with some error
you MUST give connection back to the request and finalize it:

    $r->give_connection;
    $r->finalize_request(NGX_DONE);
    
    return NGX_NOOP;

Usually you will also need to return NGX_NOOP instead of NGX_CLOSE,
since your connection is going to be closed within http request's
finalizer. But it shouldn't cuase any problems either way.

=head1 TIPS AND TRICKS

=head2 SELF-SUFFICIENT HANDLERS

It's important to know how and actually fairly easy to create 
self-sufficient reusable handlers for B<nginx-perl>.

Just remember couple of things: 

1. Use C<< $r->location_name >> as a prefix:

    location /foo/ {
        perl_handler My::handler;
    }

    sub handler {
        ...
        
        my $prefix =  $r->location_name;
           $prefix =~ s/\/$//;
        
        $out = "<a href=$prefix/something > do something </a>";
        # will result in "<a href=/foo/something > do something </a>"
        ...
    }

2. Use C<< $r->variable >> to configure handlers and to access per-server 
and per-location variables:

    location /foo/ {
        set $conf_bar "baz";
        perl_handler My::handler;
    }

    sub handler {
        ...
        
        my $conf_bar      = $r->variable('conf_bar');
        my $document_root = $r->variable('document_root');
        ...
    }

3. Use C<< $r->ctx >> to exchange arbitrary data between handlers:

    sub handler {
        ...
        
        my $ctx = { foo => 'bar' };
        $r->ctx($ctx);
        
        my $ctx = $r->ctx;
        ...
    }

4. Use C<perl_eval> to configure your modules directly 
from F<nginx-perl.conf>:

    http {
        
        perl_require  MyModule.pm;
        
        perl_eval  ' $My::CONF{foo} = "bar" ';
    }


    package My;
    
    our %CONF = ();
    
    sub handler {
        ...
        
        warn $CONF{foo};
        ...
    }

Check out F<eg/self-sufficient> to see all this in action:

    % ./objs/nginx-perl -p eg/self-sufficient

=head1 EXAMPLES

=head2 REQUEST QUEUE

In B<nginx-perl> every request object C<$r> is created and destroyed with 
nginx's own request. This means, that it is possible to reorder natural
request flow in any way you want. It can be very helpful in case of DDOS,
unusual load spikes or anything else you can think of.

Request queuing is going to illustrate this feature.

Let's start by defining variables for our simple queueing system:

    our @QUEUE;
    our $MAX_ACTIVE_REQUESTS = 4;
    our $ACTIVE_REQUESTS = 0;

Next, let's create an access handler that does actual queueing:

    sub access_handler {
        my ($r) = @_;
        
        if ($ACTIVE_REQUESTS < $MAX_ACTIVE_REQUESTS) {
            $ACTIVE_REQUESTS++;
            
            return NGX_OK;
        } else {
            $r->log_error(0, "Too many concurrent requests, queueing");
            
            push @QUEUE, $r;
            
            return NGX_DONE;
        }
    }

Simple enough. But now we need a way to process our queue of requests.
We are going to do this by creating our own destructor for request object.
Every request object is blessed with C<Nginx> package, so C<Nginx::DESTROY>
is what we need:

    sub Nginx::DESTROY {
        if (@QUEUE == 0) {
            $ACTIVE_REQUESTS--;
        } else {
            my $r = shift @QUEUE;
            
            $r->log_error(0, "Dequeuing");
            
            $r->phase_handler_inc;
            $r->core_run_phases;
        }
    }

That's it. Here's how to use it:

    perl_require  Requestqueue.pm;
    
    server {
        location = /index.html {
            perl_access  Requestqueue::access_handler;
        }
    }

Look for working example in F<eg/>.

Things to remember: access handler can be called multiple times depending
on your configuration; workers don't share data between each other. 

=head1 SEE ALSO

L<Nginx::Test>, L<Nginx::Util>, L<Nginx::Redis>,
L<http://zzzcpan.github.com/nginx-perl>,
L<http://wiki.nginx.org/EmbeddedPerlModule>,
L<http://nginx.net/> 

=head1 AUTHOR

Igor Sysoev,
Alexandr Gomoliako <zzz@zzz.org.ua>

=head1 COPYRIGHT AND LICENSE

Copyright (C) Igor Sysoev

Copyright 2011 Alexandr Gomoliako. All rights reserved.

This module is free software. It may be used, redistributed and/or modified 
under the same terms as B<nginx> itself.

=cut


