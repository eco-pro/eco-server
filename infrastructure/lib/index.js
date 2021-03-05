import EcoServerStack from "./eco-server-stack.js";
import PackageDBStack from "./package-db-stack.js";

export default function main(app) {
  new PackageDBStack(app, "eco-package-db");
  //new EcoServerStack(app, "eco-server");
}
