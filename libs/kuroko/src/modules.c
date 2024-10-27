#include <kuroko/vm.h>

#include <string.h>

#ifdef KRK_BUNDLE_LIBS

extern int krk_init_modules(void);

void krk_module_init_libs(void) {
#define BUNDLED(name) do { \
	extern KrkValue krk_module_onload_ ## name (KrkString*); \
	KrkValue moduleOut = krk_module_onload_ ## name (NULL); \
	krk_attachNamedValue(&vm.modules, # name, moduleOut); \
	krk_attachNamedObject(&AS_INSTANCE(moduleOut)->fields, "__name__", (KrkObj*)krk_copyString(#name, sizeof(#name)-1)); \
	krk_attachNamedValue(&AS_INSTANCE(moduleOut)->fields, "__file__", NONE_VAL()); \
} while (0)
    BUNDLED(_pheap);
    BUNDLED(dis);
    BUNDLED(fileio);
    BUNDLED(gc);
    BUNDLED(locale);
    BUNDLED(math);
    BUNDLED(os);
    BUNDLED(random);
    // BUNDLED(socket);
    BUNDLED(stat);
    BUNDLED(time);
    BUNDLED(timeit);
    BUNDLED(wcwidth);

    krk_init_modules();
}

#endif

/**
 * @brief Compile and execute a source code input as builtin module.
 *
 * @param src           Source code of the module.
 * @param moduleName    The name of the module.
 * @return 1 if the module was loaded, 0 if an exception occurred.
 */
int krk_exec_module(const char* src, const char* moduleName) {
    KrkString* runAs = krk_copyString(moduleName, strlen(moduleName));
    KrkInstance * enclosing = krk_currentThread.module;
    krk_startModule(runAs->chars);
    
    char fromFile[64];
    snprintf(fromFile, sizeof(fromFile), "<%s>", moduleName);

    krk_interpret(src, fromFile);
    KrkValue moduleOut = OBJECT_VAL(krk_currentThread.module);
    krk_currentThread.module = enclosing;
    if (!IS_OBJECT(moduleOut) || (krk_currentThread.flags & KRK_THREAD_HAS_EXCEPTION)) {
        if (!(krk_currentThread.flags & KRK_THREAD_HAS_EXCEPTION)) {
            krk_runtimeError(vm.exceptions->importError,
                "Failed to load module '%S'", moduleName);
        }
        krk_tableDelete(&vm.modules, OBJECT_VAL(runAs));
        krk_resetStack();
        return 0;
    }
    return 1;
}
