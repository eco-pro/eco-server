**Status** - 22-Jan-2020

An outline of the API used by `package.elm-lang.org` has been created using `the-sett/elm-serverless`. This forwards all requests to that site, and relays the responses back to the caller.

The elm compiler can successfully run through this.

Start this package server:

```
npm install
npm start
```

Set up a proxy using mitmproxy. You will need to set up its certificate authority on your system, or Elm will not manage to download through the proxy. There instructions on doing this are here: [https://docs.mitmproxy.org/stable/concepts-certificates/]

```
mitmdump --ssl-insecure -M '|https://package.elm-lang.org/|http://localhost:3000/'
```

Try running an elm build through it:

```
https_proxy=http://127.0.0.1:8080 elm make
```

# eco-server

An alternative package server for Elm.
