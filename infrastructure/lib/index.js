import BuildJobStack from "./build-job-stack.js";
import PackageDBStack from "./package-db-stack.js";

export default function main(app) {
  new PackageDBStack(app, "package-db");
  //new BuildJobStack(app, "dev-build-job");
}
