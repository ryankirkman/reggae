/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;

import reggae.config; // isDubProject

static if(isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;
    import std.typecons;
    import std.traits;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(Flags compilerFlags = Flags())() {
        enum config = "default";
        const dubInfo = configToDubInfo[config];
        enum exeName = dubInfo.exeName;
        enum linkerFlags = dubInfo.mainLinkerFlags;
        return dubTarget!(() { Target[] t; return t;})
            (
                exeName,
                dubInfo,
                compilerFlags.value,
                Yes.main,
                No.allTogether,
                linkerFlags
            );
    }

    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(ExeName exeName,
                                  Configuration config = Configuration("default"),
                                  Flags compilerFlags = Flags(),
                                  Flag!"main" includeMain = Yes.main,
                                  Flag!"allTogether" allTogether = No.allTogether,
                                  alias objsFunction = () { Target[] t; return t; },
                                  )
        () if(isCallable!objsFunction)
    {

        return dubTarget!(objsFunction)(exeName,
                                        configToDubInfo[config.value],
                                        compilerFlags.value,
                                        includeMain,
                                        allTogether);
    }

    Target dubTestTarget(Flags compilerFlags = Flags())() {
        const config = "unittest" in configToDubInfo ? "unittest" : "default";

        auto actualCompilerFlags = compilerFlags.value;
        if("unittest" !in configToDubInfo) actualCompilerFlags ~= " -unittest";

        const hasMain = configToDubInfo[config].packages[0].mainSourceFile != "";
        const linkerFlags = hasMain ? [] : ["-main"];

        // since dmd has a bug pertaining to separate compilation and __traits(getUnitTests),
        // we default here to compiling all-at-once for the unittest build
        return dubTarget!()(ExeName("ut"),
                            configToDubInfo[config],
                            actualCompilerFlags,
                            Yes.main,
                            Yes.allTogether,
                            linkerFlags);
    }


    Target dubTarget(alias objsFunction = () { Target[] t; return t;})
                    (in ExeName exeName,
                     in DubInfo dubInfo,
                     in string compilerFlags,
                     in Flag!"main" includeMain = Yes.main,
                     in Flag!"allTogether" allTogether = No.allTogether,
                     in string[] linkerFlags = [])
    {

        import std.array: join;

        const allLinkerFlags = (linkerFlags ~ dubInfo.linkerFlags).join(" ");
        auto dubObjs = dubInfo.toTargets(includeMain, compilerFlags, allTogether);
        return link(exeName,
                    objsFunction() ~ dubObjs ~ dubInfo.staticLibrarySources(),
                    Flags(allLinkerFlags));
    }


    /**
     All object files from a particular dub configuration (executable, unittest, etc.)
     */
    Target[] dubConfigurationObjects(Configuration config = Configuration("default"),
                                     Flags compilerFlags = Flags(),
                                     alias objsFunction = () { Target[] t; return t; },
                                     Flag!"main" includeMain = No.main)
        () if(isCallable!objsFunction) {
        return configToDubInfo[config.value].toTargets(includeMain, compilerFlags.value);
    }
}
