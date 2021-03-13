import VpcBaseStack from "./vpc-base-stack.js";

export default function main(app) {
  new VpcBaseStack(app, "vpc-base-stack");
}
