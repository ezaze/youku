#!/usr/bin/perl -w
# Based on source code below:
# http://aws.amazon.com/code/128
# http://github.com/timkay/aws
# http://www.perltutorial.org/
# 
# Signing and Authenticating in Amazon:
# http://docs.amazonwebservices.com/AmazonS3/latest/dev/RESTAuthentication.html
# Signing and Authenticating in Sina S3:
# http://sinastorage.sinaapp.com/developer/interface/aws/auth.html
# About SinaWatch Alert Service:
# http://wiki.intra.sina.com.cn/pages/viewpage.action?pageId=7162793

# WARNING: It isn't safe to put your kid/passwd on the
# command line! The recommended strategy is to store
# your kid/passwd in this scripts owned by, and only readable
# by you.
my $kid = "2012101713";
my $passwd = "XCSN1h7cywzcBwtOA2MndonTnLLT7R";

my $curl = "curl";
my $url = "http://iconnect.monitor.sina.com.cn/v1/alert/send";
# For waiwang, use connect.monitor.sina.com.cn
# my $url = "http://connect.monitor.sina.com.cn/v1/alert/send";
my $host = "";
my $port = "";
my $path = "";
my $query = "";

my $sv;
my $service;
my $object;
my $subject;
my $content = "";
my $html = 0;

my $mailto = "";
my $msgto = "";
my $ivrto = "";
my $gmailto = "";
my $gmsgto = "";
my $givrto = "";

my $debug = 0;
my $help = 0;

# http://turtle.ee.ncku.edu.tw/docs/perl/manual/lib/Getopt/Long.html
use Getopt::Long qw(GetOptions);
GetOptions(
    'kid:s' => \$kid,
    'passwd:s' => \$passwd,
    'sv=s' => \$sv,
    'service=s' => \$service,
    'object=s' => \$object,
    'subject=s' => \$subject,
    'content:s' => \$content,
    'html' => \$html,

    'mailto:s' => \$mailto,
    'msgto:s' => \$msgto,
    'ivrto:s' => \$ivrto,
    'gmailto:s' => \$gmailto,
    'gmsgto:s' => \$gmsgto,
    'givrto:s' => \$givrto,

    'url:s' => \$url,

    'debug' => \$debug,
    'help' => \$help,
);

my $usage = <<USAGE;
Usage $0 --sv "monitor" --service "service" --object "object" --subject "subject" --msgto "someone,otherone" [options]
 please go to http://wiki.intra.sina.com.cn/pages/viewpage.action?pageId=7162793 for more details.
 options:
  --kid             kid for your application
                    visit http://wiki.intra.sina.com.cn/pages/viewpage.action?pageId=7162775 for more details
  --passwd          password for your kid

  --sv              sv
  --service         service
  --object          object
  --subject         subject
  --content         content
  --html            html

  --mailto          contacts (split by comma)
  --msgto           contacts (split by comma)
  --ivrto           contacts (split by comma)
  --gmailto         contact groups (split by comma)
  --gmsgto          contact groups (split by comma)
  --givrto          contact groups (split by comma)

  --url             change the default url.

  --debug           enable debug logging
  --help            help usage

 # WARNING: It isn't safe to put your kid/passwd on the
 # command line! The recommended strategy is to store
 # your kid/passwd in this scripts owned by, and only readable
 # by you.
USAGE
die $usage if $help || !defined $sv || !defined $service || !defined $object || !defined $subject;
die "Give one contacts atleast.\n" if $mailto eq "" && $msgto eq "" && $ivrto eq "" && $gmailto eq "" && $gmsgto eq "" && $givrto eq "";

sub send_alert {
    my $method = "POST";
    my $contentType = "application/x-www-form-urlencoded";
    my $timestamp = local_timestamp() + 600;
    my $ip = local_ip();

    my $xHeaders;
    if ($ip ne "") {
        $xHeaders{'x-sinawatch-ip'} = trim($ip);
    }
    my $xHeadersToSign = "";
    foreach (sort (keys %xHeaders)) {
        my $headerValue = $xHeaders{$_};
        $xHeadersToSign .= "$_:$headerValue\n";
    }

    my $xResouce;
    ($host, $port, $path, $query) = parse_url($url);
    $xResouce = $path;

    my $postdata = "sv=$sv&service=$service&object=$object&subject=$subject&content=$content&html=$html&mailto=$mailto&msgto=$msgto&ivrto=$ivrto&gmailto=$gmailto&gmsgto=$gmsgto&givrto=$givrto";
    my $contentMD5 = md5($postdata);

    my $stringToSign = "$method\n$contentMD5\n$contentType\n$timestamp\n$xHeadersToSign$xResouce";

    debug("stringToSign='" . $stringToSign . "'");
    my $signature = encode_base64(hmac($stringToSign, $passwd, \&sha1_sha1), "");
    $signature = substr $signature, 5, 10;
    debug("signature='" . $signature);

    @curl_options = check_curl();

    my @args = ();
    push @args, @curl_options;
    push @args, ("-H", "Expires: $timestamp");
    push @args, ("-H", "Authorization: sinawatch $kid:$signature");
    push @args, ("-H", "x-sinawatch-ip: $ip") if (defined $ip);
    push @args, ("-L");
    push @args, ("-H", "Content-Type: $contentType") if (defined $contentType);
    push @args, ("-H", "Content-MD5: $contentMD5") if (length $contentMD5);
    push @args, ("-X", "POST");
    push @args, ("-d", $postdata);
    push @args, $url;

    debug("exec $curl " . join (" ", @args));
    exec($curl, @args) or die "can't exec program: $!";
}

send_alert();

sub check_curl {
    my @curl_options = ();
    push @curl_options, ("-q", "-g", "-S");
    push @curl_options, ("--progress-bar") if $debug;
    push @curl_options, ("--verbose") if $debug;
    push @curl_options, ("--max-time", "10");

    my($curl_version) = qx[$curl -V] =~ /^curl\s+([\d\.]+)/s;
    debug("curl version: $curl_version");
    if (xcmp($curl_version, "7.12.3") < 0) {
        debug("curl-check: This curl (v$curl_version) does not support --retry (>= v7.12.3), so --retry is disabled");
    }
    else {
        push @curl_options, ("--retry", "3");
    }
    return @curl_options;
}

sub xcmp {
    my($a, $b) = @_? @_: ($a, $b);
    @a = split(//, $a);
    @b = split(//, $b);

    for (;;) {
        return @a - @b unless @a && @b;

        last if $a[0] cmp $b[0];

        shift @a;
        shift @b;
    }
    my $cmp = $a[0] cmp $b[0];
    for (;;) {
        if (!defined($a[0])) { $a[0] = ""; }
        if (!defined($b[0])) { $b[0] = ""; }
        return ($a[0] =~ /\d/) - ($b[0] =~ /\d/) if ($a[0] =~ /\d/) - ($b[0] =~ /\d/);
        last unless (shift @a) =~ /\d/ && (shift @b) =~ /\d/;
    }
    return $cmp;
}

sub local_timestamp {
    return time;
}

sub local_ip {
    my @ifconfig = "/sbin/ifconfig | grep -v 127.0.0.1";
    my @ip = trim(`@ifconfig -a` =~ /inet [adr:]*(\S+)/);
    if (@ip eq "") {
        @ip = local_ip_2();
    }
    return "@ip";
}

# http://www.perlmonks.org/?node_id=53660
sub local_ip_2 {
    use strict;
    use warnings;
    require 'sys/ioctl.ph';
    use Socket;
    use Data::Dumper;

    my %interfaces;
    my $max_addrs = 30;
    socket(my $socket, AF_INET, SOCK_DGRAM, 0) or die "socket: $!";
    {
        my $ifreqpack = 'a16a16';
        my $buf = pack($ifreqpack, '', '') x $max_addrs;
        my $ifconf = pack('iP', length($buf), $buf);

        # This does the actual work
        ioctl($socket, SIOCGIFCONF(), $ifconf) or die "ioctl: $!";

        my $len = unpack('iP', $ifconf);
        substr($buf, $len) = '';

        %interfaces = unpack("($ifreqpack)*", $buf);

        unless (keys(%interfaces) < $max_addrs) {
            # Buffer was too small
            $max_addrs += 10;
            redo;
        }
    }

    my $ip;
    for my $addr (values %interfaces) {
        $addr = inet_ntoa((sockaddr_in($addr))[1]);
        if ($addr ne "127.0.0.1") {
            $ip = $addr;
            last;
        }
    }
    return $ip;
}

sub parse_url {
    my ($url) = @_;

    if ($url =~ /https?:\/\/([^\/:?]+)(?::(\d+))?([^?]*)(?:\?(\S+))?/) {
        $host = $1 if !$host;
        my $port = defined $2 ? $2 : 80;
        my $path = $3;
        my $query = defined $4 ? $4 : "";
        debug("Found the url: host=$host; port=$port; uri=$path; query=$query.");
        return ($host, $port, $path, $query);
    }
    else {
        debug("Wrong url format.");
    }
}

sub debug {
    my ($str) = @_;
    $str =~ s/\n/\\n/g;
    print STDERR "$str\n" if ($debug);
}

sub trim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub ltrim($) {
    my $string = shift;
    $string =~ s/^\s+//;
    return $string;
}

sub rtrim($) {
    my $string = shift;
    $string =~ s/\s+$//;
    return $string;
}

sub encode_url {
    my($s) = @_;
    $s =~ s/([^\-\.0-9a-z\_\~])/%@{[uc unpack(H2,$1)]}/ig;
    $s;
}

sub decode_url {
    my($s) = @_;
    $s =~ s/%(..)/@{[uc pack(H2,$1)]}/ig;
    $s;
}

sub md5 {
    use Digest::MD5;
    my ($string) = @_;

    my $md5 = Digest::MD5->new;
    $md5->add($string);
    return $md5->hexdigest;
}

sub hmac {
    my($data, $key, $hash_func, $block_size) = @_;
    $block_size ||= 64;
    $key = &$hash_func($key) if length($key) > $block_size;

    my $k_ipad = $key ^ (chr(0x36) x $block_size);
    my $k_opad = $key ^ (chr(0x5c) x $block_size);

    &$hash_func($k_opad, &$hash_func($k_ipad, $data));
}

sub sha1_sha1 {
    # integer arithment should be mod 32
    use integer;

    my $msg = join("", @_);

    #constants [4.2.1]
    my @K = (0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xca62c1d6);

    # PREPROCESSING

    $msg .= pack(C, 0x80); # add trailing '1' bit to string [5.1.1]

    # convert string msg into 512-bit/16-integer blocks arrays of ints [5.2.1]
    my @M = unpack("N*", $msg . pack C3);
    # how many integers are needed (to make complete 512-bit blocks), including two words with length
    my $N = 16 * int((@M + 2 + 15) / 16);
    # add length (in bits) into final pair of 32-bit integers (big-endian) [5.1.1]
    @M[$N - 2, $N - 1] = (sha1_lsr(8 * length($msg), 29), 8 * (length($msg) - 1));

    # set initial hash value [5.3.1]
    my @H = (0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0);

    # HASH COMPUTATION [6.1.2]
    for (my $i = 0; $i < $N; $i += 16)
    {
        # 1 - prepare message schedule 'W'
        my @W = @M[$i..$i + 15];

        # 2 - initialise five working variables a, b, c, d, e with previous hash value
        my($a, $b, $c, $d, $e) = @H;

        # 3 - main loop
        for (my $t = 0; $t < 80; $t++)
        {
            if (!defined($W[$t])) {
                $W[$t] = 0;
            }
            $W[$t] = sha1_rotl($W[$t - 3] ^ $W[$t - 8] ^ $W[$t - 14] ^ $W[$t - 16], 1) if $t >= 16;
            my $s = int($t / 20); # seq for blocks of 'f' functions and 'K' constants
            my $T = sha1_rotl($a, 5) + sha1_f($s, $b, $c, $d) + $e + $K[$s] + $W[$t];
            ($e, $d, $c, $b, $a) = ($d, $c, sha1_rotl($b, 30), $a, $T);
        }

        # 4 - compute the new intermediate hash value
        $H[0] += $a;
        $H[1] += $b;
        $H[2] += $c;
        $H[3] += $d;
        $H[4] += $e;
    }

    pack("N*", @H);
}

sub sha1_f {
    my($s, $x, $y, $z) = @_;

    return ($x & $y) ^ (~$x & $z) if $s == 0;
    return $x ^ $y ^ $z if $s == 1 || $s == 3;
    return ($x & $y) ^ ($x & $z) ^ ($y & $z) if $s == 2;
}

sub sha1_rotl {
    my($x, $n) = @_;
    ($x << $n) | (($x & 0xffffffff) >> (32 - $n));
}

sub sha1_lsr {
    no integer;
    my($x, $n) = @_;
    $x / 2 ** $n;
}

sub encode_base64 ($;$) {
    if ($] >= 5.006) {
    require bytes;
    if (bytes::length($_[0]) > length($_[0]) ||
            ($] >= 5.008 && $_[0] =~ /[^\0-\xFF]/))
    {
        require Carp;
        Carp::croak("The Base64 encoding is only defined for bytes");
    }
    }

    use integer;

    my $eol = $_[1];
    $eol = "\n" unless defined $eol;

    my $res = pack("u", $_[0]);
    # Remove first character of each line, remove newlines
    $res =~ s/^.//mg;
    $res =~ s/\n//g;

    $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
    # fix padding at the end
    my $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
    # break encoded string into lines of no more than 76 characters each
    if (length $eol) {
    $res =~ s/(.{1,76})/$1$eol/g;
    }
    return $res;
}

sub decode_base64 ($) {
    local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]
    use integer;

    my $str = shift;
    $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
    if (length($str) % 4) {
    require Carp;
      Carp::carp("Length of base64 data not a multiple of 4")
      }
    $str =~ s/=+$//;                        # remove padding
    $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
    return "" unless length $str;

    ## I guess this could be written as
    #return unpack("u", join('', map( chr(32 + length($_)*3/4) . $_,
    #$str =~ /(.{1,60})/gs) ) );
    ## but I do not like that...
    my $uustr = '';
    my ($i, $l);
    $l = length($str) - 60;
    for ($i = 0; $i <= $l; $i += 60) {
    $uustr .= "M" . substr($str, $i, 60);
    }
    $str = substr($str, $i);
    # and any leftover chars
    if ($str ne "") {
    $uustr .= chr(32 + length($str)*3/4) . $str;
    }
    return unpack ("u", $uustr);
}

