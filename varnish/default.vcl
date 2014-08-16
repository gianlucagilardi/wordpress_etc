
vcl 4.0;
# Varnish configuration for wordpress
# AdminGeekZ Ltd <sales@admingeekz.com>
# URL: www.admingeekz.com/varnish-wordpress
# Version: 1.5

#Configure the backend webserver
backend default {
  .host = "127.0.0.1";
  .port = "8080";
}

# Have separate backend for wp-admin for longer timesouts
backend wpadmin {
  .host = "127.0.0.1";
  .port = "8080";
  .first_byte_timeout = 500000s;
  .between_bytes_timeout = 500000s;
}


#Which hosts are allowed to PURGE the cache
acl purge {
  "127.0.0.1";
}


sub vcl_recv {
  if (req.method == "BAN") {
    if(!client.ip ~ purge) {
      return (synth(405, "Not allowed."));
    }
    ban("req.url ~ "+req.url+" && req.http.host == "+req.http.host);
    return (synth(200, "Banned."));
  }

  if (req.method != "GET" &&
      req.method != "HEAD" &&
      req.method != "PUT" &&
      req.method != "POST" &&
      req.method != "TRACE" &&
      req.method != "OPTIONS" &&
      req.method != "DELETE") {
    return (pipe);
  }

  if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
  }

  #Don't cache admin or login pages
  if (req.url ~ "wp-(login|admin)" || req.url ~ "preview=true") {
    return (pass);
  }

  #Don't cache logged in users
  if (req.http.Cookie && req.http.Cookie ~ "(wordpress_|wordpress_logged_in|comment_author_)") {
 return(pass);
  }

  #Don't cache ajax requests, urls with ?nocache or comments/login/regiser
  if(req.http.X-Requested-With == "XMLHttpRequest" || req.url ~ "nocache" || req.url ~ "(control.php|wp-comments-post.php|wp-login.php|register.php)") {
    return (pass);
  }

  #Set backend to wpadmin backend for longer timeouts
  if (req.url ~ "/wp-admin") {
     set req.backend_hint = wpadmin;
  }

  #Serve stale cache objects for up to 2 minutes if the backend is down
  # set req.grace = 120s;

  #Remove all cookies if none of the above match
  unset req.http.cookie;

  return (hash);
}

sub vcl_backend_response {
  #Don't cache error pages
  if (beresp.status >= 400) {
    set beresp.ttl = 0m;
    return(deliver);
  }

  if (bereq.url ~ "wp-(login|admin)" || bereq.url ~ "preview=true") {
	set beresp.uncacheable = true;
	return (deliver);
  }

  if (bereq.http.Cookie ~"(wp-postpass|wordpress_logged_in|comment_author_)") {
	set beresp.uncacheable = true;
	return (deliver);
  }

  #Set the default cache time of 12 hours
  set beresp.ttl = 12h;
  return (deliver);
}

sub vcl_hash {

  #Uncomment if you use multiple domains/subdomains and want to maintain separate caches
  #hash_data(req.http.host);
  #Uncomment if you use SSL and want to maintain separate caches
  #hash_data(req.http.X-Forwarded-Port);

  #Set the hash to include the cookie if it exists, to maintain per user cache
  if ( req.http.Cookie ~"(wp-postpass|wordpress_logged_in|comment_author_)" ) {
    hash_data(req.http.Cookie);
  }
}


#Comment this out if you don't want to see weather there was a HIT or MISS in the headers
sub vcl_deliver {
        if (obj.hits > 0) {
                set resp.http.X-Cache = "HIT";
        } else {
                set resp.http.X-Cache = "MISS";
        }
}




