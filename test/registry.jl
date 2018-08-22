module RegistryTest

using Test
using Pkg
using Pkg.Types
using PkgDev
import LibGit2

include("utils.jl")

replace_in_file(f, pat) = write(f, replace(read(f, String), pat))

temp_pkg_dir() do project_path; cd(project_path) do
    # Create a registry
    registry_path = joinpath(DEPOT_PATH[1], "registries", "CustomReg");
    PkgDev.Registry.create_registry(registry_path, repo = registry_path, description = "This is a reg")
    pkgs = mktempdir()
    PkgDev.generate(joinpath(pkgs, "TheFirst"), "MIT")
    @show registry_path
    @show read(joinpath(pkgs, "TheFirst", "Project.toml"), String)
    PkgDev.Registry.register(registry_path, joinpath(pkgs, "TheFirst"))
    # Version already installed
    @test_throws PkgError PkgDev.Registry.register(registry_path, joinpath(pkgs, "TheFirst"))
    Pkg.add("TheFirst")
    @test Pkg.installed()["TheFirst"] == v"0.1.0"
     # Add an stdlib dep and update it to v0.2.0
    p = joinpath(pkgs, "TheFirst")
    Pkg.activate(p)
    Pkg.add("Random")
    replace_in_file(joinpath(p, "Project.toml"), "version = \"0.1.0\"" => "version = \"0.2.0\"")
    LibGit2.with(LibGit2.GitRepo(p)) do repo
        LibGit2.add!(repo, "*")
        LibGit2.commit(repo, "tag v0.2.0")
    end
    Pkg.activate()
    PkgDev.Registry.register(registry_path, joinpath(pkgs, "TheFirst"))
    Pkg.up()
    @test Pkg.installed()["TheFirst"] == v"0.2.0"
    Pkg.rm("TheFirst")
    pkg"add TheFirst@0.1.0"
    @test Pkg.installed()["TheFirst"] == v"0.1.0"
    Pkg.rm("TheFirst")
     # Add a new package that depends on TheFirst
    cd(pkgs) do
        create_package("TheSecond")
    end
    Pkg.activate(joinpath(pkgs, "TheSecond"))
    println("adding uuid...")
    Pkg.add("UUIDs")
    println("adding the first")
    Pkg.add("TheFirst")
     # Add a compat to TheFirst
    open(joinpath(pkgs, "TheSecond", "Project.toml"), "a") do io
        print(io, """
        [compat]
        TheFirst = "0.1.0"
        """)
    end
    LibGit2.with(LibGit2.GitRepo(joinpath(pkgs, "TheSecond"))) do repo
        LibGit2.add!(repo, "*")
        LibGit2.commit(repo, "tag v0.1.0")
    end
    Pkg.activate()
    PkgDev.Registry.register(registry_path, joinpath(pkgs, "TheSecond"))
    Pkg.add("TheSecond")
    @test Pkg.installed()["TheFirst"] == v"0.1.0"
    @test Pkg.installed()["TheSecond"] == v"0.1.0"
end end

end # module
