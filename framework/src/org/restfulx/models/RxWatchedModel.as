package org.restfulx.models {
	import flash.utils.Dictionary;

	import mx.events.PropertyChangeEvent;

	import org.restfulx.models.RxModel;
	import org.restfulx.utils.RxUtils;

	public class RxWatchedModel extends RxModel {
		private var _changedPropertiesCount:int = 0;
		public var _changedProperties:Dictionary;

		public function RxWatchedModel(label:String = "id") {
			super(label);
			resetDirty();
			addEventListener("propertyChange", onPropertyChange);
		}

		protected function onPropertyChange(event:PropertyChangeEvent):void {
			if (RxUtils.isEmpty(id)) {
				dirty = true;
				return;
			}

			if ((event.kind == "update") && (event.oldValue != event.newValue)) {
				if ((event.property == 'dirty') && (event.newValue == false)) {
					resetDirty();
					return;
				}

				if (RxUtils.isInvalidPropertyName(event.property.toString()))
					return;

				if (_changedProperties[event.property]) {
					if (_changedProperties[event.property] == event.newValue) {
						delete _changedProperties[event.property];
						_changedPropertiesCount--;
					}
				} else {
					_changedProperties[event.property] = event.oldValue;
					_changedPropertiesCount++;
				}
				dirty = _changedPropertiesCount != 0;
			}
		}

		public function resetDirty():void {
			_changedPropertiesCount = 0;
			_changedProperties = new Dictionary();
		}

		public function rollbackChanges():void {
			for (var property:String in _changedProperties) {
				this[property] = _changedProperties[property];
			}
			resetDirty();
		}

		public function save(optsOrOnSuccess:Object = null, onFailure:Function = null, nestedBy:Array = null, metadata:Object = null, recursive:Boolean = false, targetServiceId:int = -1):Boolean {
			if (!dirty) {
				return false;
			}

			if (RxUtils.isEmpty(id)) {
				create(optsOrOnSuccess, onFailure, nestedBy, metadata, recursive, targetServiceId);
			} else {
				update(optsOrOnSuccess, onFailure, nestedBy, metadata, recursive, targetServiceId);
			}
			return true;
		}

	}
}

