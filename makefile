.PHONY: bench profile stat flame clean

codegen = 0
ifneq ($(codegen), 0)
	codegenflag = --codegen
else
	codegenflag =
endif

parser = "parser"
rate = 10000
out = $(parser)
limit = 10

bench:
	luau bench/init.luau $(codegenflag) -a $(parser)

profile:
	@mkdir profile -p
	luau bench/init.luau $(codegenflag) --profile=$(rate) -a $(parser)
	@mv profile.out profile/$(out).out

stats: profile
	@chmod +x scripts/perfstat.py
	@scripts/perfstat.py profile/$(out).out --limit=$(limit)

flame: profile
	@chmod +x scripts/perfgraph.py
	@scripts/perfgraph.py profile/$(out).out > profile/$(out).svg

clean:
	@rm -r profile
	@rm -r scripts/__pycache__
	echo "cleaned"