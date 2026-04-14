import { application } from "controllers/application";

import CopyButtonController from "components/copy_button/component";
application.register("copy-to-clipboard", CopyButtonController);

import IssueViewToggleController from "components/issue_view_toggle/component";
application.register("issue-view-toggle", IssueViewToggleController);
