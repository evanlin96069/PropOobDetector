#include <kuroko/vm.h>

#ifdef KRK_BUNDLE_LIBS

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
}

#endif
