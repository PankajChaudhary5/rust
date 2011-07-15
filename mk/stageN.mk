# StageN template: arg 1 is the N we're building *from*, arg 2 is N+1.
#
# The easiest way to read this template is to assume we're building stage2
# using stage1, and mentally gloss $(1) as 1, $(2) as 2.

define STAGEN

# Host libraries and executables (stage$(2)/rustc and its runtime needs)
#
# NB: Due to make not wanting to run the same implicit rules twice on the same
# rule tree (implicit-rule recursion prevention, see "Chains of Implicit
# Rules" in GNU Make manual) we have to re-state the %.o and %.s patterns here
# for different directories, to handle cases where (say) a test relies on a
# compiler that relies on a .o file.

STAGE$(2) := $$(Q)$$(call CFG_RUN_TARG,stage$(2),stage$(1), \
                $$(CFG_VALGRIND_COMPILE) stage$(2)/rustc$$(X) \
                $$(CFG_RUSTC_FLAGS))

stage$(2)/%.o: stage$(2)/%.s
	@$$(call E, assemble [gcc]: $$@)
	$$(Q)gcc $$(CFG_GCCISH_CFLAGS) -o $$@ -c $$<

stage$(2)/rustc$$(X): $$(COMPILER_CRATE) $$(COMPILER_INPUTS) \
                      stage$(2)/$$(CFG_RUNTIME)              \
                      stage$(2)/$$(CFG_STDLIB)               \
                      stage$(2)/$$(CFG_RUSTLLVM)             \
                      $$(SREQ$(1))
	@$$(call E, compile_and_link: $$@)
	$$(STAGE$(1)) -L stage$(2) -o $$@ $$<

stage$(2)/$$(CFG_RUNTIME): rt/$$(CFG_RUNTIME)
	@$$(call E, cp: $$@)
	$$(Q)cp $$< $$@

stage$(2)/$$(CFG_STDLIB): stage$(1)/lib/$$(CFG_STDLIB)
	@$$(call E, cp: $$@)
	$$(Q)cp $$< $$@

stage$(2)/$$(CFG_RUSTLLVM): rustllvm/$$(CFG_RUSTLLVM)
	@$$(call E, cp: $$@)
	$$(Q)cp $$< $$@


# Target libraries (for binaries generated by stage$(2)/rustc)

stage$(2)/lib/intrinsics.bc: $$(INTRINSICS_BC)
	@$$(call E, cp: $$@)
	$$(Q)cp $$< $$@

stage$(2)/lib/glue.o: stage$(2)/rustc$$(X)        \
                      stage$(2)/$$(CFG_RUNTIME)   \
                      stage$(2)/$$(CFG_RUSTLLVM)  \
                      stage$(2)/lib/intrinsics.bc \
                      $$(SREQ$(1))
	@$$(call E, generate: $$@)
	$$(STAGE$(2)) -c -o $$@ --glue

stage$(2)/lib/$$(CFG_STDLIB): $$(STDLIB_CRATE) $$(STDLIB_INPUTS) \
                              stage$(2)/rustc$$(X)               \
                              stage$(2)/$$(CFG_RUNTIME)          \
                              stage$(2)/$$(CFG_RUSTLLVM)         \
                              stage$(2)/lib/glue.o               \
                              $$(SREQ$(1))
	@$$(call E, compile_and_link: $$@)
	$$(STAGE$(2))  --lib -o $$@ $$<

stage$(2)/lib/libstd.rlib: $$(STDLIB_CRATE) $$(STDLIB_INPUTS) \
                           stage$(2)/rustc$$(X)               \
                           stage$(2)/$$(CFG_RUNTIME)          \
                           stage$(2)/$$(CFG_RUSTLLVM)         \
                           stage$(2)/lib/glue.o               \
                           $$(SREQ$(1))
	@$$(call E, compile_and_link: $$@)
	$$(STAGE$(2)) --lib --static -o $$@ $$<


stage$(2)/lib/main.o: rt/main.o
	@$$(call E, cp: $$@)
	$$(Q)cp $$< $$@

stage$(2)/lib/$$(CFG_RUNTIME): rt/$$(CFG_RUNTIME)
	@$$(call E, cp: $$@)
	$$(Q)cp $$< $$@

stage$(2)/lib/$$(CFG_LIBRUSTC): $$(COMPILER_CRATE) $$(COMPILER_INPUTS) \
                                $$(SREQ$(2))
	@$$(call E, compile_and_link: $$@)
	$$(STAGE$(2)) --lib -o $$@ $$<

endef

# Instantiate template for 0->1, 1->2, 2->3 build dirs

$(eval $(call STAGEN,0,1))
$(eval $(call STAGEN,1,2))
$(eval $(call STAGEN,2,3))
