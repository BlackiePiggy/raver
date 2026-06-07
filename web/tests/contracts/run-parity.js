const Module = require("node:module");
const path = require("node:path");

const originalResolveFilename = Module._resolveFilename;
const distRoot = path.resolve(__dirname, "dist/web");

Module._resolveFilename = function patchedResolveFilename(request, parent, isMain, options) {
  if (typeof request === "string" && request.startsWith("@/")) {
    const mapped = path.join(distRoot, "src", request.slice(2));
    return originalResolveFilename.call(this, mapped, parent, isMain, options);
  }
  return originalResolveFilename.call(this, request, parent, isMain, options);
};

require("./dist/web/tests/contracts/event-mapper-parity.js");
require("./dist/web/tests/contracts/event-status-display-parity.js");
require("./dist/web/tests/contracts/event-status-cross-platform-parity.js");
require("./dist/web/tests/contracts/event-ios-mutation-compat-parity.js");
