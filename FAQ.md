## Frequently Asked Questions

##### Do I have to learn Lua to use the MML compiler?
No, but you need to learn its basic syntax if you want to create MML engines. The fact you can write them by learning Lua is already a vast improvement over the other MML compilers that have their own hardcoded implementations.

##### So, why Lua?
Lua is compact but still powerful enough for multiple programming paradigms. It is easy to learn and its reference documentation fits in a single page. More importantly, a number of emulators such as FCEUX and BizHawk support Lua scripting out of the box -- if you have done any intermediate ROM hacking before, you probably already know how to write Lua code.

##### I have installed MGCInts through LuaRocks, where have my files gone?
The source code goes to `/share/lua/5.x/mgcints`, and everything else goes to `/lib/luarocks/rocks/mgcints/(rockspec version)/`. The rocks tree directory is shown after installing MGCInts or invoking LuaRocks with no options.

##### I have installed MGCInts through LuaRocks on Windows, but my computer cannot locate the frontend.
Most likely, you have not set up your environment variables properly as stated near the end of the LuaRocks installer batch script.

##### Can I target multiple games using the same MML file?
If the MML engine explicitly supports multiple games, your MML will work on all of them (with different track numbers); otherwise, depending on the difference in expressive power between the engines, the MML file might or might not be able to hide engine-specific details into conditionally compiled preprocessor blocks.
