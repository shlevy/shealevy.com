let
  pkgs = import <nixpkgs> {};
  base = ./wordpress-migration;
  recurse = dir: if builtins.pathExists (dir + "/body")
    then [ dir ]
    else let
      subs = builtins.attrNames (builtins.readDir dir);
    in builtins.concatLists (map (sub: recurse (dir + "/${sub}")) subs);
  wp-posts = builtins.listToAttrs (map (post: let pubDate = import (post + "/pub-date"); in {
    name = toString pubDate;
    value = {
      inherit pubDate;
      title = builtins.readFile (post + "/title");
      body = builtins.readFile (post + "/body");
      path = builtins.substring ((builtins.stringLength (toString base)) + 1) (builtins.stringLength (toString post)) (toString post);
    };
  }) (recurse base));
  modern-posts = [
    { title = "Wrapping My Head Around Cubical Path Types"; path = "2020/04/29/wrapping-my-head-around-cubical-path-types"; file = ./cubical-path-typing-rules/post.html; }
    { title = "Understanding Nix's String Context"; path = "2018/08/05/understanding-nix's-string-context"; file = ./nix-string-context/post.html; }
  ];
  wp-posts-ordered = map (pubDate: wp-posts.${toString pubDate}) (builtins.sort (x: y: builtins.lessThan y x) (map ({ pubDate, ... }: pubDate) (builtins.attrValues wp-posts)));
  posts-ordered = modern-posts ++ wp-posts-ordered;
  make-wp-page = title: body: path: pkgs.writeText "index.html" ''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Shea's Blog - ${title}</title>
      </head>
      <body>
        <nav><a href="/">Home</a></nav>
        <h1>${title}</h1>
        <p>Note: This post has been automatically imported from my old blog. Formatting may be incorrect.</p>
        ${body}
        <div id="disqus_thread"></div>
        <script>
          var disqus_config = function () {
            this.page.url = "http://blog.shealevy.com/${path}/";
          };
          (function() {
            var d = document; s = d.createElement('script');
            s.src = '//shealevy.disqus.com/embed.js';
            s.setAttribute('data-timestamp', +new Date());
            (d.head || d.body).appendChild(s);
          })();
        </script>
        <noscript>>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
      </body>
    </html>
  '';
  index = pkgs.writeText "index.html" ''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <title>Shea's Blog</title>
      </head>
      <body>
        <nav>
          <ul>
            ${builtins.concatStringsSep "\n        " (map (post:
              "<li><a href=\"${post.path}/\">${post.title}</a></li>"
            ) posts-ordered)}
          </ul>
        </nav>
      </body>
    <html>
  '';
  make-tree-command = ''
    mkdir $out
    cp ${index} $out/index.html
  '' + builtins.concatStringsSep "\n" (map (post: ''
    mkdir -p $out/"${post.path}"
    cp ${make-wp-page post.title post.body post.path} $out/${post.path}/index.html
  '') wp-posts-ordered) + builtins.concatStringsSep "\n" (map (post: ''
    mkdir -p $out/"${post.path}"
    cp ${post.file} $out/"${post.path}"/index.html
  '') modern-posts);
in pkgs.runCommand "blog" {} ''
  ${make-tree-command}
''
