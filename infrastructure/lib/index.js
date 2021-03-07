import EcoServerStack from "./build-job-stack.js";
import PackageDBStack from "./package-db-stack.js";

export default function main(app) {
  new PackageDBStack(app, "eco-package-db");
  //new BuildJobStack(app, "eco-server");
}
