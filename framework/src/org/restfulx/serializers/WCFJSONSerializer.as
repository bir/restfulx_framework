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
package org.restfulx.serializers {
	import com.adobe.serialization.json.JSON;

	import flash.utils.getQualifiedClassName;

	import org.restfulx.models.RxModel;
	import org.restfulx.utils.RxUtils;
	import org.restfulx.utils.TypedArray;

	/**
	 * Serialises <code>RxModel</code> instances to JSON and back.
	 */
	public class WCFJSONSerializer extends JSONSerializer {

		/**
		 *  @inheritDoc
		 */
		public override function marshall(object:Object, recursive:Boolean = false):Object {
			var vo:Object = $marshall(object, recursive);
			var localName:String = RxUtils.toSnakeCase(vo["clazz"]);
			delete vo["clazz"];
			return JSON.encode(vo);
		}

		protected override function unmarshallJSONObject(source:Object, disconnected:Boolean = false):Object {
			if (source.hasOwnProperty("d")) {
				// .NET WCF style JSON
				if (source.d is Array)
					return unmarshallJSONArray(source.d, disconnected);
				source = source.d;
			}
			if (!source.hasOwnProperty("id") && !source.hasOwnProperty("_id")) {
				// ActiveRecord-like JSON array with element names as object keys
				for (var prop:String in source) {
					var target:Object = source[prop];
					target["clazz"] = prop;
					source = target;
					break;
				}
			} else {
				// try CouchDB-like convention
				convertProperties(source);
			}

			return $unmarshall(source, disconnected);
		}

		protected override function convertProperties(instance:Object):Object {
			for each (var prop:Object in[{"_id": "id"}, {"etag": "id"}, {"_rev": "rev"}, {"ruby_class": "clazz"}, {"couchrest-type": "clazz"}, {"__metadata": "clazz"}]) {
				for (var key:String in prop) {
					if (instance.hasOwnProperty(key)) {
						var target:String = prop[key];
						if ((key == "__metadata") && (instance[key].hasOwnProperty("type"))) {
							instance[target] = instance[key]["type"];
						} else
							instance[target] = instance[key];
						delete instance[key];
					}
				}
			}
			return instance;
		}
	}
}