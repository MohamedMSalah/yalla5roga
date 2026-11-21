import type { Application, Router } from "express";

type Layer = { handle: { stack?: Layer[] }; route?: { path: string; methods: Record<string, boolean> }; match(path: string): boolean };
const prefixes = new WeakMap<Router, string>();
export function mountRoutes(parent: Router, path: string, child: Router) {
  prefixes.set(child, path);
  parent.use(path, child);
}

export function registeredRoutes(app: Application) {
  const routes: { method: string; path: string; pattern: RegExp }[] = [];
  function walk(stack: Layer[], parent: string) {
    for (const layer of stack) {
      if (layer.route) {
        const path = (parent + layer.route.path).replace(/\/$/, "") || "/";
        const pattern = new RegExp("^" + path.split("/").map(part => part.startsWith(":")
          ? "[^/]+" : part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("/") + "/?$", "i");
        for (const [method, registered] of Object.entries(layer.route.methods)) {
          if (registered) routes.push({ method: method.toUpperCase(), path, pattern });
        }
      } else if (layer.handle.stack) {
        const prefix = prefixes.get(layer.handle as unknown as Router);
        if (!prefix && !layer.match("/")) throw new Error("Route router prefix must be registered with mountRoutes");
        walk(layer.handle.stack, parent + (prefix ?? ""));
      }
    }
  }
  walk(app.router.stack as unknown as Layer[], "");
  return routes;
}

export function compareSwagger(routes: ReturnType<typeof registeredRoutes>, spec: object) {
  const methods = new Set(["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]);
  const actual = routes.filter(route => route.path.startsWith("/api/"));
  const registered = new Set(actual.map(({ method, path }) => `${method} ${path}`));
  const paths = (spec as { paths?: Record<string, Record<string, unknown>> }).paths ?? {};
  const documented = new Set(Object.entries(paths).flatMap(([path, operations]) =>
    path.startsWith("/api/") ? Object.keys(operations)
      .filter(method => methods.has(method.toUpperCase()))
      .map(method => `${method.toUpperCase()} ${path.replace(/\{(\w+)\}/g, ":$1")}`) : []));
  const optionalMockRoutes = new Set(["GET /api/media/mock-download/:key", "PUT /api/media/mock-upload/:key"]);
  const missing = [...registered].filter(key => !documented.has(key)).sort();
  return {
    apiRoutes: actual.length, documentedApiRoutes: documented.size,
    optionalUndocumented: missing.filter(key => optionalMockRoutes.has(key)),
    undocumented: missing.filter(key => !optionalMockRoutes.has(key)),
    unregistered: [...documented].filter(key => !registered.has(key)).sort(),
    duplicated: actual.length - registered.size,
  };
}
