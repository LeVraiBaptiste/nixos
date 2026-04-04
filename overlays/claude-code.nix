# Custom claude-code overlay
# Override when nixpkgs version is yanked from npm
final: prev: {
  claude-code = final.stdenv.mkDerivation rec {
    pname = "claude-code";
    version = "2.1.90";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-jknJDrrsVltfsK90S+vFPB/TYmJFPLTzCcEvYSe1VBg=";
    };

    nativeBuildInputs = [ final.makeWrapper ];
    buildInputs = [ final.nodejs_22 ];

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/claude-code
      cp -r . $out/lib/claude-code/

      # Fix bridge spawner for Node.js 22+
      sed -i 's|execPath:process\.execPath,env:process\.env|execPath:process.argv[1],env:process.env|' \
        $out/lib/claude-code/cli.js

      mkdir -p $out/bin
      makeWrapper ${final.nodejs_22}/bin/node $out/bin/claude \
        --add-flags "-- $out/lib/claude-code/cli.js" \
        --set DISABLE_AUTOUPDATER 1 \
        --set DISABLE_INSTALLATION_CHECKS 1

      runHook postInstall
    '';

    postFixup = ''
      sed -i '1s|^#!\(.*\)/bin/node.*|#!\1/bin/node --|' $out/lib/claude-code/cli.js
    '';

    meta = with final.lib; {
      description = "Claude Code CLI - Official Anthropic CLI for Claude";
      homepage = "https://github.com/anthropics/claude-code";
      license = licenses.unfree;
      mainProgram = "claude";
    };
  };
}
