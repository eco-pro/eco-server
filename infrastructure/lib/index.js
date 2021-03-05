import EcoServerStack from "./eco-server-stack.js";

export default function main(app) {
  new EcoServerStack(app, "eco-server");
}
