#!/usr/bin/env perl
use strict;
use warnings;
use Furl::HTTP;
use File::Path ();
use File::Spec;
use Getopt::Long;
use JSON;
use URI;

GetOptions(\my %opt, "key=s", "user=s", "output=s");
if (!$opt{key} || !$opt{user}) {
    die "Usage: $0 --key=<API_KEY> --user=<GOOGLEPLUS_USER_ID> \n";
}
unless ( $opt{output} ) {
    $opt{output} = './'. $opt{user};
}
my $i = 1;
my $url = sprintf 'https://www.googleapis.com/plus/v1/people/%s/activities/public', $opt{user};
my $furl = Furl::HTTP->new;
unless ( -d $opt{output} ) {
    File::Path::mkpath($opt{output});
}

sub get_attachments {
    my( $user_id, $params ) = @_;
    $params ||= {};
    $params->{key} = $opt{key};
    $params->{maxResults} = 50;
    my $uri = URI->new( $url );
    $uri->query_form( $params );
    my(undef, $code, undef, undef, $body) = $furl->request(
        method => 'GET',
        url => $uri,
    );
    die $body unless $code eq '200';
    my $json = decode_json( $body );
    for my $item(@{$json->{items}}) {
        my $basename = $item->{id};
        my $n = 1;
        for my $attachment(@{$item->{object}{attachments}}) {
            if ($attachment->{objectType} eq 'photo') {
                my $image = $attachment->{fullImage}{url};
                my $filename = sprintf '%s-%s.jpg', $basename, $n++;
                save_image( $image, $filename );
            } elsif ($attachment->{objectType} eq 'album') {
                my $thumbnails = $attachment->{thumbnails};
                for my $thumbnail(@{$thumbnails}) {
                    my $image = $thumbnail->{image}{url};
                    # See http://programming.kuribo.info/2011/07/google_24.html
                    $image =~ s|([^/]+)/([^/]+)$|s0/$2|;
                    my $filename = sprintf '%s-%s.jpg', $basename, $n++;
                    save_image( $image, $filename );
                }
            }
        }
    }
    my $json_file = sprintf 'posts-%02d.json', $i;
    my $json_path = File::Spec->catfile( $opt{output}, $json_file );
    open my $fh, '>', $json_path or die "$!: $json_path";
    print $fh $body;
    close $fh;
    $i++;
    if (my $token = $json->{nextPageToken}) {
        get_attachments( $user_id, { pageToken => $token });
    } 
}

sub save_image {
    my( $image, $filename ) = @_;
    my $path = File::Spec->catfile( $opt{output}, $filename );
    unless (-e $path) {
        open my $fh, '>', $path or die "$!: $path";
        $furl->request(
            method => 'GET',
            url => $image,
            write_file => $fh,
        );
    }
}

get_attachments( $opt{user} );


__END__


