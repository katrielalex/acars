# Edit tamarin-build.conf not this file, probably

# Copy the file remotely and run Tamarin on it
default: m4 remote

# Find the smallest unused port > 3000 on ${host}; thanks http://unix.stackexchange.com/a/55940
# There's a race condition (if someone binds that port in the middle of the make) but it's hardly important
# Choose a local port for Tamarin (FYI you need -n in lsof or it takes 20s for DNS resolution... yuck)
init-vars:
	$(eval browser := open)
	$(eval remotefile := ${remotefile})
	$(eval include tamarin-build.conf)

	$(eval remoteport := $(shell ssh -t ${host} "ss -tln | awk 'NR > 1{gsub(/.*:/,"\"\"",\$$4); print \$$4}' | sort -un | awk -v n=3001 '\$$0 < n {next}; \$$0 == n {n++; next}; {exit}; END {print n}'"))
	$(eval localport := $(shell lsof -n -i -P | grep -i "listen" | grep -o "[0-9]* (LISTEN)" | cut -d' ' -f1 | sort -un | awk -v n=3001 '$$0 < n {next}; $$0 == n {n++; next}; {exit}; END {print n}'))


# copy to remote, open a browser, and compile there
remote: init-vars
	scp proto.spthy ${host}:${remotefile} > /dev/null
	@echo ========= local port ${localport}, remote port ${remoteport} =========
	(tail -f ${logfile} | grep -m1 "Application launched" | xargs echo "" >> ${logfile}; ${browser} http://localhost:${localport}/thy/trace/1/overview/help) &
	ssh -L ${localport}:localhost:${remoteport} -S'none' -t ${host} "${tamarin} interactive ${remotefile} --interface='*4' --port=${remoteport} ${tamarin-args}" 2>&1 | tee ${logfile}

local: m4
	tamarin-prover interactive . --interface="*4" --heuristic=i

m4: 
	m4 secure_ACARS.m4 > proto.spthy

preview: server.PID

server.PID:
	websocketd --port=8080 --staticdir=. ./read-log ${logfile} & echo $$! > server.PID

stop: server.PID
	kill `cat $<` && rm $<

