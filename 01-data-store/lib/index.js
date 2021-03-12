import PackageDBStack from "./package-db-stack.js";

export default function main(app) {
  new PackageDBStack(app, "package-db");
}
