**Status** - 22-Jan-2020

An outline of the API used by `package.elm-lang.org` has been created using `the-sett/elm-serverless`. This forwards all requests to the original package site, and relays the responses back to the caller.

The elm compiler can successfully run through this.

Start this package server:

```
npm install
npm start
```

Set up a proxy using mitmproxy. You will need to set up its certificate authority on your system, or Elm will not manage to download through the proxy. The instructions on doing this are here: https://docs.mitmproxy.org/stable/concepts-certificates/

```
mitmdump --ssl-insecure -M '|https://package.elm-lang.org/|http://localhost:3000/'
```

Try running an elm build through it:

```
https_proxy=http://127.0.0.1:8080 elm make
```

# Development Roadmap
#### (just some notes on where this is going in the immediate future)

* Set up a domain with a proper certificate and deploy this onto AWS.

* Download and cache all the .zip files, and service requests independently of package.elm-lang.org. At this point there is a usable backup of the main package site, useful if that is down.

# eco-server

An alternative package server for Elm.
