{
  config,
  inputs,
  lib,
  ...
}:
let
  published = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ ];
    imports = [
      inputs.flake-parts.flakeModules.modules
      ../../checks/modules/publications.nix
      ../../checks/modules/more.nix
    ];
  };
  nx = published.modules.nixos;
  hm = published.modules.homeManager;
  schema.options.marks = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };
  run =
    class: modules:
    (lib.evalModules {
      inherit class;
      modules = [ schema ] ++ modules;
    }).config.marks;
  same =
    actual: expected:
    builtins.sort builtins.lessThan actual == builtins.sort builtins.lessThan expected;
  plain.marks = [ "plain" ];
  fun = { ... }: { marks = [ "function" ]; };
  located = {
    _file = "one-diagnostic-location";
    marks = [ "located" ];
  };
  identified = {
    key = "fixture:identified";
    marks = [ "identified" ];
  };
  instance = name: {
    key = "fixture:instance:${name}";
    imports = [ (lib.modules.importApply ../../checks/modules/factory.nix name) ];
  };
  parent = {
    key = "fixture:parent";
    imports = [ plain ];
  };
  conflicting =
    keyA: keyB:
    (lib.evalModules {
      modules = [
        { options.number = lib.mkOption { type = lib.types.int; }; }
        {
          key = keyA;
          number = 1;
        }
        {
          key = keyB;
          number = 2;
        }
      ];
    }).config.number;
  system = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.home-manager
      schema
      nx.alpha
      nx.beta
      nx.left
      nx.right
      nx.multi
      {
        nixpkgs.hostPlatform = "x86_64-linux";
        system.stateVersion = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        users.users = {
          alice = {
            isNormalUser = true;
            home = "/srv/alice";
          };
          bob.isNormalUser = true;
        };
        home-manager.sharedModules = [ schema ];
        home-manager.users = {
          alice = {
            home.stateVersion = "26.05";
            imports = [
              hm.alpha
              hm.beta
              hm.left
              hm.right
              hm.multi
            ];
          };
          bob = {
            home.stateVersion = "25.11";
            imports = [
              hm.multi
              hm.multi
            ];
          };
        };
      }
    ];
  };
  results = {
    identity = {
      class-labels-also-distinguish-contributions-in-untyped-evaluation =
        same
          (run null [
            nx.alpha
            hm.alpha
          ])
          [
            "system-alpha"
            "home-alpha"
          ];
      public-address-is-not-contribution-key =
        run "nixos" [
          nx.address-a
          nx.address-b
        ] == [ "implementation" ];
      independent-nixos-capabilities-in-one-file =
        same
          (run "nixos" [
            nx.alpha
            nx.beta
          ])
          [
            "system-alpha"
            "system-beta"
          ];
      independent-home-capabilities-in-one-file =
        same
          (run "homeManager" [
            hm.alpha
            hm.beta
          ])
          [
            "home-alpha"
            "home-beta"
          ];
      multifile-capability = same (run "nixos" [ nx.multi ]) [
        "system-a"
        "system-b"
      ];
      multiple-contributions-to-one-name-in-one-file = same (run "nixos" [ nx.intra ]) [
        "intra-a"
        "intra-b"
      ];
      same-name-in-independent-classes =
        run "nixos" [ nx.alpha ] == [ "system-alpha" ]
        && run "homeManager" [ hm.alpha ] == [ "home-alpha" ];
      parameterized-instances-without-keys =
        same
          (run "nixos" [
            (lib.modules.importApply ../../checks/modules/factory.nix "left")
            (lib.modules.importApply ../../checks/modules/factory.nix "right")
          ])
          [
            "left"
            "right"
          ];
      parameterized-instances-with-distinct-keys =
        same
          (run "nixos" [
            (instance "left")
            (instance "right")
            (instance "left")
          ])
          [
            "left"
            "right"
          ];
      wrong-class-rejected =
        !(builtins.tryEval (builtins.deepSeq (run "nixos" [ hm.alpha ]) true)).success;
      different-keys-preserve-option-conflicts =
        !(builtins.tryEval (conflicting "first" "second")).success;
    };
    deduplication = {
      direct-path-is-automatic =
        run "nixos" [
          ../../checks/modules/path.nix
          ../../checks/modules/path.nix
        ] == [ "path" ];
      imported-function-loses-path-identity =
        run "nixos" [
          (import ../../checks/modules/path.nix)
          (import ../../checks/modules/path.nix)
        ] == [
          "path"
          "path"
        ];
      anonymous-attrset-occurrences-are-distinct =
        run "nixos" [
          plain
          plain
        ] == [
          "plain"
          "plain"
        ];
      anonymous-function-occurrences-are-distinct =
        run "nixos" [
          fun
          fun
        ] == [
          "function"
          "function"
        ];
      file-metadata-is-not-a-key =
        run "nixos" [
          located
          located
        ] == [
          "located"
          "located"
        ];
      explicit-key-merges-once =
        run "nixos" [
          identified
          identified
        ] == [ "identified" ];
      identified-parent-needs-no-key-on-private-child =
        run "nixos" [
          parent
          parent
        ] == [ "plain" ];
      anonymous-helper-identity-is-relative-to-parent =
        run "nixos" [
          {
            key = "fixture:parent-a";
            imports = [ plain ];
          }
          {
            key = "fixture:parent-b";
            imports = [ plain ];
          }
        ] == [
          "plain"
          "plain"
        ];
      identified-helper-in-diamond =
        run "nixos" [
          {
            key = "fixture:parent-a";
            imports = [ identified ];
          }
          {
            key = "fixture:parent-b";
            imports = [ identified ];
          }
        ] == [ "identified" ];
      repeated-publication =
        same
          (run "nixos" [
            nx.multi
            nx.multi
          ])
          [
            "system-a"
            "system-b"
          ];
      system-diamond =
        same
          (run "nixos" [
            nx.left
            nx.right
            nx.multi
          ])
          [
            "system-a"
            "system-b"
          ];
      home-diamond =
        same
          (run "homeManager" [
            hm.left
            hm.right
            hm.multi
          ])
          [
            "home-a"
            "home-b"
          ];
      native-nixos-and-home-manager-evaluate = builtins.isString system.config.system.build.toplevel.drvPath;
      native-nixos-merge = same system.config.marks [
        "system-alpha"
        "system-beta"
        "system-a"
        "system-b"
      ];
      native-home-manager-merge = same system.config.home-manager.users.alice.marks [
        "home-alpha"
        "home-beta"
        "home-a"
        "home-b"
      ];
      deduplication-does-not-cross-accounts = same system.config.home-manager.users.bob.marks [
        "home-a"
        "home-b"
      ];
      native-account-identity-preserved =
        system.config.home-manager.users.alice.home.homeDirectory == "/srv/alice"
        && system.config.home-manager.users.bob.home.homeDirectory == "/home/bob";
    };
    counterexamples = {
      file-only-key-loses-independent-contribution =
        builtins.length (
          run "nixos" [
            {
              key = __curPos.file;
              marks = [ "first" ];
            }
            {
              key = __curPos.file;
              marks = [ "second" ];
            }
          ]
        ) == 1;
      capability-only-key-loses-multifile-contribution =
        builtins.length (
          run "nixos" [
            {
              key = "fixture:one-capability";
              _file = "first-file";
              marks = [ "first" ];
            }
            {
              key = "fixture:one-capability";
              _file = "second-file";
              marks = [ "second" ];
            }
          ]
        ) == 1;
      same-key-hides-option-conflict = (builtins.tryEval (conflicting "same" "same")).success;
      same-key-can-discard-a-different-instance =
        builtins.length (
          run "nixos" [
            {
              key = "fixture:factory";
              imports = [ (lib.modules.importApply ../../checks/modules/factory.nix "left") ];
            }
            {
              key = "fixture:factory";
              imports = [ (lib.modules.importApply ../../checks/modules/factory.nix "right") ];
            }
          ]
        ) == 1;
    };
  };
in
{
  perSystem = { pkgs, ... }: {
    checks.module-system =
      assert lib.assertMsg (builtins.all (x: x) (
        lib.collect builtins.isBool results
      )) "Module identity/deduplication checks failed: ${builtins.toJSON results}";
      pkgs.writeText "module-system-checks.json" (builtins.toJSON results);
  };
}
