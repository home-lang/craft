fun main() {
    check(craftAppLinkPathMatches("/m/*", "/m/people"))
    check(craftAppLinkPathMatches("/m/*", "/m/"))
    check(craftAppLinkPathMatches("/?*", "/a")) { "?* must match a nonempty segment" }
    check(!craftAppLinkPathMatches("/?*", "/")) { "?* must not match an empty segment" }
    check(craftAppLinkPathMatches("/files/?.pdf", "/files/a.pdf"))
    check(!craftAppLinkPathMatches("/files/?.pdf", "/files/ab.pdf"))
    check(!craftAppLinkPathMatches("/*/?*", "/diego-ruiz/"))
    check(craftAppLinkPathMatches("/*/?*", "/coaches/athletes/"))
    check(!craftAppLinkPathMatches("/gyms/*/?*", "/gyms/trifit/"))
    check(craftAppLinkPathMatches("/gyms/*/?*", "/gyms/trifit/admin"))
    check(craftAppLinkPathMatches("/a+b/[x]", "/a+b/[x]"))
    check(!craftAppLinkPathMatches("/a+b/[x]", "/aaab/x"))
    check(craftAppLinkPathMatches("/emoji/?", "/emoji/😀"))
    println("Android App Link path wildcards: passed")
}
