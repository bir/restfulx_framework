/*******************************************************************************
 * Copyright (c) 2008-2009 Dima Berastau and Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Redistributions of files must retain the above copyright notice.
 ******************************************************************************/
package org.restfulx.services.http {
	import flash.utils.getQualifiedClassName;

	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.rpc.http.HTTPService;

	import org.restfulx.Rx;
	import org.restfulx.collections.ModelsCollection;
	import org.restfulx.controllers.ServicesController;
	import org.restfulx.serializers.ISerializer;
	import org.restfulx.serializers.WCFJSONSerializer;
	import org.restfulx.services.UndoRedoResponder;
	import org.restfulx.utils.RxUtils;

	/**
	 * .NET WCF JSON-over-HTTP service provider based on Flex HTTPService.
	 */
	public class WCFJSONHTTPServiceProvider extends JSONHTTPServiceProvider {

		/** service id */
		public static const ID:int = ServicesController.generateId();

		override protected function get serializer():ISerializer {
			if (!_serializer)
				_serializer = new WCFJSONSerializer();
			return _serializer;
		}

		/**
		 * @param httpRootUrl root URL that this service provider will prefix to all requests.
		 *  By default this will be equal to Rx.httpRootUrl parameter
		 */
		public function WCFJSONHTTPServiceProvider(httpRootUrl:String = null) {
			super(httpRootUrl);
			urlSuffix = "$format=json";
		}

		/**
		 * @see org.restfulx.services.IServiceProvider#id
		 */
		public override function get id():int {
			return ID;
		}

		/**
		 * @see org.restfulx.services.IServiceProvider#hasErrors
		 */
		public override function hasErrors(object:Object):Boolean {
			// TODO: what are we doing about the errors sent over in JSON?
			return false;
		/* Sample error response from WCF
		   {
		   "error": {
		   "code": "", "message": {
		   "lang": "en-US", "value": "MIME type \'application/x-www-form-urlencoded\' is not supported for POST operations to this resource."
		   }
		   }

		 */
		}

		protected override function getHTTPService(object:Object, nestedBy:Array = null):HTTPService {
			var service:HTTPService = super.getHTTPService(object, nestedBy);
			service.resultFormat = "text";
			// TODO: HACK - support for WCF JSON
			service.contentType = "application/json";
			service.url = rootUrl + RxUtils.nestResource(object, nestedBy, urlSuffix, "?");
			return service;
		}




		protected override function invokeCreateOrUpdateHTTPService(service:HTTPService, responder:IResponder, object:Object, metadata:Object = null, nestedBy:Array = null, recursive:Boolean = false, undoRedoFlag:int = 0, creating:Boolean = false):void {
			Rx.log.debug("sending request to URL:" + service.url + " with method: " + service.method + " and content:" + ((service.request == null) ? "null" : "\r" + service.request.toString()));

			var instance:Object = this;

			var urlParams:String = urlEncodeMetadata(metadata);
			if (urlParams != "") {
				service.url += "&" + urlParams;
			}
			service.addEventListener(ResultEvent.RESULT, function(event:ResultEvent):void {
					onHttpResult(event);
					var result:Object = event.result;
					if (hasErrors(result)) {
						if (responder)
							responder.result(event);
					} else {
						var fqn:String = getQualifiedClassName(object);

						if (!creating) {
							var cached:Object = RxUtils.clone(ModelsCollection(Rx.models.cache.data[fqn]).withId(object["id"]));
						}

						// TODO WCF.NET - hacked because .NET WCF DataService does not return the object on the update
						var response:Object;
						if ((result is String) && RxUtils.isEmpty(String(result))) {
							response = ModelsCollection(Rx.models.cache.data[fqn]).withId(object["id"]);
							response.dirty = false;
						} else {
							response = unmarshall(result);
						}

						if (Rx.enableUndoRedo && undoRedoFlag != Rx.undoredo.UNDO) {
							var target:Object;
							var clone:Object = RxUtils.clone(response);
							var action:String = "destroy";
							var fn:Function = Rx.models.cache.destroy;

							if (!creating) {
								target = cached;
								target["rev"] = object["rev"];
								action = "update";
								fn = Rx.models.cache.update;
							} else {
								target = RxUtils.clone(response);
							}

							Rx.undoredo.addChangeAction({service: instance, action: action, copy: clone, elms: [target, new UndoRedoResponder(responder, fn), metadata, nestedBy, recursive]});
						}

						RxUtils.fireUndoRedoActionEvent(undoRedoFlag);
						if (responder)
							responder.result(new ResultEvent(ResultEvent.RESULT, false, false, response));
					}
				});
			service.addEventListener(FaultEvent.FAULT, function(event:FaultEvent):void {
					if (responder)
						responder.fault(event);
				});
			service.send();
		}



	}
}