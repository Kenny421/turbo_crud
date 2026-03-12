import { Application } from "@hotwired/stimulus"
const application = Application.start()

import TurboCrudController from "./turbo_crud_controller"
import TurboCrudFlashController from "./turbo_crud_flash_controller"
application.register("turbo-crud", TurboCrudController)
application.register("turbo-crud-flash", TurboCrudFlashController)
