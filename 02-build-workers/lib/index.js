import BuildJobStack from "./build-job-stack.js";

export default function main(app) {
  new BuildJobStack(app, "dev-build-job");
}
