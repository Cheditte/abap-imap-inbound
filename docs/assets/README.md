# Documentation images

`business-need-tr.jpg` and `business-need-en.jpg` are Canva-generated editorial illustrations for this project's README and community articles. Their purpose is to explain the need, the approach and a first trial to both functional and technical SAP readers.

The illustrations are conceptual, not SAP screenshots. They make no claim that the demonstration creates business documents. Actual setup and verification limits are documented in the walkthrough and README. Keep equivalent alt text when reusing an image, and retain readable text when resizing.

`diagrams/` contains the English and Turkish SVG diagrams used by the README and walkthrough. Text is split into explicit lines inside generous boxes; there are no HTML labels or clipping regions. This keeps the diagrams readable across Markdown viewers.

Regenerate the SVGs after changing their text or layout:

```shell
node docs/assets/diagrams/render.cjs
```

The generator uses only Node.js built-ins. It is a documentation tool, with no SAP/server runtime dependency. The diagrams cover project use, the three-part installation map, mailbox folder flow, SAP host preparation and the SAP ERP installation sequence.
